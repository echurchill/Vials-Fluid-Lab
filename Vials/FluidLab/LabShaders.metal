#include <metal_stdlib>
using namespace metal;

struct Particle { float4 position; float4 predicted; float4 velocity; float4 visual; };
struct Uniforms {
    float4x4 viewProjection, inverseViewProjection, view;
    float4 camera, viewport, physics;
    uint4 options;
};
struct Vessel { float4x4 world, inverseWorld, previousWorld; float4 dimensions, marks; };
struct Vertex { float4 position, normal; };
// Include sources approaching the outside of either edge receiver.
constant uint gridCount = 128*48*40;

float radiusAt(float y, constant Vessel &v, device const float *profiles) {
    float f = clamp(y / v.dimensions.x, 0.0f, 1.0f) * 127;
    uint i = min(uint(f),126u), offset = uint(v.dimensions.y)*128;
    return mix(profiles[offset+i], profiles[offset+i+1], f-float(i));
}
int3 gridCell(float3 p, float h) { return int3(floor((p+float3(12.8,0.4,3.8))/0.20f)); }
uint gridIndex(int3 c) { c=clamp(c,int3(0),int3(127,47,39)); return uint(c.x+128*(c.y+48*c.z)); }
float poly6(float r2, float h) {
    float q = max(0.0f,1-r2/(h*h));
    return 1.56668147f/(h*h*h)*q*q*q;
}
float3 spiky(float3 d, float h) {
    float r=length(d);
    if (r<0.00001f || r>=h) return float3(0);
    float q=1-r/h;
    return -14.3239449f/(h*h*h*h)*q*q*d/r;
}

float4 collide(float4 point, constant Vessel *vessels, device const float *profiles, uint vesselCount=2, bool board=false, bool eligible=true) {
    float3 p=point.xyz;
    int owner=int(round(point.w));
    const float margin=0.034;
    if (owner>=0 && owner<int(vesselCount)) {
        constant Vessel &v=vessels[owner];
        float3 local=(v.inverseWorld*float4(p,1)).xyz;
        if (local.y>v.dimensions.x+margin && (!board || (eligible && v.dimensions.w==1))) owner=-1;
        else {
            if(board && (!eligible || v.dimensions.w!=1)) local.y=min(local.y,v.dimensions.x-margin);
            local.y=max(local.y,margin);
            float r=radiusAt(local.y,v,profiles)-margin;
            float radial=length(local.xz);
            if (radial>r) local.xz*=max(r,0.01f)/max(radial,0.0001f);
            p=(v.world*float4(local,1)).xyz;
        }
    }
    if (owner<0) {
        for (uint i=0;i<vesselCount;i++) {
            constant Vessel &v=vessels[i];
            float3 local=(v.inverseWorld*float4(p,1)).xyz;
            float r=radiusAt(local.y,v,profiles);
            float radial=length(local.xz);
            if ((!board || v.dimensions.w==2) && local.y<=v.dimensions.x+margin && local.y>v.dimensions.x-0.26 && radial<r-margin*0.5) {
                owner=i;
                break;
            }
            if (local.y>=0 && local.y<v.dimensions.x && radial>=r-margin && radial<r+v.dimensions.z+margin) {
                local.xz*= (r+v.dimensions.z+margin)/max(radial,0.0001f);
                p=(v.world*float4(local,1)).xyz;
            }
        }
    }
    p.y=max(p.y,0.045f);
    float boardHalfWidth=max(9.5f,(float(max(2u,vesselCount))-1.0f)*1.1f+1.2f);
    p.xz=clamp(p.xz,float2(board ? -boardHalfWidth:-3.7,board ? -3.5:-2.35),float2(board ? boardHalfWidth:3.7,board ? 3.3:2.35));
    return float4(p,float(owner));
}

// A temporary, invisible cone guides near-misses above the active mouth.
// It only redirects selected airborne liquid; ownership still changes at
// the real opening. A short throat follows the inner rim so a fast particle
// cannot step across the lip and escape between discrete collision checks.
// Liquid farther below the rim is never pulled back.
float4 boardGuide(float4 point, constant Uniforms &u, constant Vessel *vessels,
                  device const float *profiles, bool eligible) {
    if (!(u.options.w&65536u) || !eligible || point.w>=0) return point;
    for (uint owner=0;owner<u.options.z;owner++) {
        constant Vessel &v=vessels[owner];
        if (v.dimensions.w!=2) continue;
        float3 local=(v.inverseWorld*float4(point.xyz,1)).xyz;
        float above=local.y-v.dimensions.x;
        const float height=1.25f, apron=0.80f;
        if (above< -0.12f || above>height) return point;
        float mouth=radiusAt(min(local.y,v.dimensions.x),v,profiles)-0.025f;
        float radial=length(local.xz),outer=mouth+apron;
        float cone=mouth+apron*max(0.0f,above/height);
        if (radial>cone && radial<=outer) {
            local.xz*=cone/max(radial,0.0001f);
            point.xyz=(v.world*float4(local,1)).xyz;
        }
        return point;
    }
    return point;
}

bool boardFrozen(Particle p, constant Uniforms &u) {
    int owner=int(round(p.position.w));
    return (u.options.w&1u) && owner>=0 && ((u.options.w>>(owner+1))&1u)==0;
}

kernel void labPredict(device Particle *p [[buffer(0)]], constant Uniforms &u [[buffer(1)]],
                       constant Vessel *v [[buffer(2)]], device const float *profiles [[buffer(3)]], uint i [[thread_position_in_grid]]) {
    if (i>=u.options.x) return;
    if(boardFrozen(p[i],u)) { p[i].predicted=p[i].position;return; }
    float3 velocity=p[i].velocity.xyz;
    velocity.y-=9.81f*u.physics.x;
    float speed=length(velocity);
    if (speed>7) velocity*=7/speed;
    float4 proposed=float4(p[i].position.xyz+velocity*u.physics.x,p[i].position.w);
    float4 guided=boardGuide(proposed,u,v,profiles,p[i].visual.z>0.5f);
    if (distance(guided.xyz,proposed.xyz)>0.00001f) p[i].visual.w=1;
    p[i].predicted=collide(guided,v,profiles,max(2u,u.options.z),(u.options.w&1u)!=0,p[i].visual.z>0.5f);
}
kernel void labClearHeads(device atomic_int *heads [[buffer(0)]], uint i [[thread_position_in_grid]]) {
    if(i<gridCount) atomic_store_explicit(&heads[i],-1,memory_order_relaxed);
}
kernel void labBuildGrid(device const Particle *p [[buffer(0)]], constant Uniforms &u [[buffer(1)]],
                         device atomic_int *heads [[buffer(2)]], device int *next [[buffer(3)]], uint i [[thread_position_in_grid]]) {
    if(i>=u.options.x) return;
    uint cell=gridIndex(gridCell(p[i].predicted.xyz,u.physics.y));
    next[i]=atomic_exchange_explicit(&heads[cell],int(i),memory_order_relaxed);
}
kernel void labLambda(device const Particle *p [[buffer(0)]], constant Uniforms &u [[buffer(1)]],
                      device atomic_int *heads [[buffer(2)]], device const int *next [[buffer(3)]],
                      device float *lambdas [[buffer(4)]], uint i [[thread_position_in_grid]]) {
    if(i>=u.options.x) return;
    float3 pos=p[i].predicted.xyz, sumGradient=0;
    float h=u.physics.y, volume=u.physics.z, density=0, denominator=0;
    int3 cell=gridCell(pos,h);
    for(int z=-1;z<=1;z++) for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
        int j=atomic_load_explicit(&heads[gridIndex(cell+int3(x,y,z))],memory_order_relaxed);
        while(j>=0) {
            float3 d=pos-p[j].predicted.xyz;
            float r2=dot(d,d);
            if(r2<h*h) {
                density+=volume*poly6(r2,h);
                float3 g=volume*spiky(d,h);
                denominator+=dot(g,g); sumGradient+=g;
            }
            j=next[j];
        }
    }
    denominator+=dot(sumGradient,sumGradient);
    lambdas[i]=-max(density-1,0.0f)/(denominator+0.2f);
}
kernel void labDelta(device const Particle *p [[buffer(0)]], constant Uniforms &u [[buffer(1)]],
                     device atomic_int *heads [[buffer(2)]], device const int *next [[buffer(3)]],
                     device const float *lambdas [[buffer(4)]], device float4 *deltas [[buffer(5)]], uint i [[thread_position_in_grid]]) {
    // Frozen particles never consume a delta in labApply. Keep their pressure
    // calculation for neighboring active particles, but omit this unused solve.
    if(i>=u.options.x || boardFrozen(p[i],u)) return;
    float3 pos=p[i].predicted.xyz, delta=0;
    float h=u.physics.y;
    int3 cell=gridCell(pos,h);
    float reference=poly6(0.09f*h*h,h);
    for(int z=-1;z<=1;z++) for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
        int j=atomic_load_explicit(&heads[gridIndex(cell+int3(x,y,z))],memory_order_relaxed);
        while(j>=0) {
            float3 d=pos-p[j].predicted.xyz;
            float r2=dot(d,d);
            if(r2<h*h && i!=uint(j)) {
                float ratio=poly6(r2,h)/reference;
                float correction=-0.00001f*ratio*ratio*ratio*ratio;
                if((u.options.w&1u) && p[i].velocity.w != p[j].velocity.w) correction-=0.0002f*ratio*ratio;
                delta+=(lambdas[i]+lambdas[j]+correction)*u.physics.z*spiky(d,h);
            }
            j=next[j];
        }
    }
    float magnitude=length(delta);
    if(magnitude>0.025f) delta*=0.025f/magnitude;
    deltas[i]=float4(delta,0);
}
kernel void labApply(device Particle *p [[buffer(0)]], constant Uniforms &u [[buffer(1)]],
                     constant Vessel *v [[buffer(2)]], device const float *profiles [[buffer(3)]],
                     device const float4 *deltas [[buffer(4)]], uint i [[thread_position_in_grid]]) {
    if(i>=u.options.x || boardFrozen(p[i],u)) return;
    float4 proposed=p[i].predicted+deltas[i];
    float4 guided=boardGuide(proposed,u,v,profiles,p[i].visual.z>0.5f);
    if (distance(guided.xyz,proposed.xyz)>0.00001f) p[i].visual.w=1;
    p[i].predicted=collide(guided,v,profiles,max(2u,u.options.z),(u.options.w&1u)!=0,p[i].visual.z>0.5f);
}
kernel void labVelocity(device const Particle *p [[buffer(0)]], constant Uniforms &u [[buffer(1)]],
                        constant Vessel *vessels [[buffer(2)]], device const float *profiles [[buffer(3)]],
                        device float4 *velocities [[buffer(4)]], uint i [[thread_position_in_grid]]) {
    if(i>=u.options.x) return;
    if(boardFrozen(p[i],u)) { velocities[i]=float4(0,0,0,p[i].velocity.w);return; }
    float3 velocity=(p[i].predicted.xyz-p[i].position.xyz)/u.physics.x;
    int owner=int(round(p[i].predicted.w));
    if(owner>=0 && owner<int(max(2u,u.options.z))) {
        constant Vessel &v=vessels[owner];
        float3 q=(v.inverseWorld*float4(p[i].predicted.xyz,1)).xyz;
        float3 wallVelocity=((v.world*float4(q,1))-(v.previousWorld*float4(q,1))).xyz/u.physics.x;
        float3 relative=velocity-wallVelocity;
        float radial=length(q.xz);
        float r=radiusAt(q.y,v,profiles);
        bool contact=false;
        if(radial > r-0.045f && radial>0.001f && q.y < v.dimensions.x) {
            float slope=(radiusAt(q.y+0.005f,v,profiles)-radiusAt(q.y-0.005f,v,profiles))/0.01f;
            float3 normal=(v.world*float4(normalize(float3(q.x/radial,-slope,q.z/radial)),0)).xyz;
            relative-=normal*max(dot(relative,normal),0.0f);
            contact=true;
        }
        if(q.y < 0.045f) {
            float3 normal=(v.world*float4(0,-1,0,0)).xyz;
            relative-=normal*max(dot(relative,normal),0.0f);
            contact=true;
        }
        if(contact) velocity=wallVelocity+relative*0.96f;
    }
    if(p[i].predicted.y<0.047) velocity.xz*=0.90;
    velocities[i]=float4(velocity,p[i].velocity.w);
}
kernel void labFinish(device Particle *p [[buffer(0)]], constant Uniforms &u [[buffer(1)]],
                      device atomic_int *heads [[buffer(2)]], device const int *next [[buffer(3)]],
                      device const float4 *velocities [[buffer(4)]], uint i [[thread_position_in_grid]]) {
    if(i>=u.options.x) return;
    if(boardFrozen(p[i],u)) return;
    float3 pos=p[i].predicted.xyz, velocity=velocities[i].xyz, correction=0;
    float h=u.physics.y, weight=0;
    int3 cell=gridCell(pos,h);
    for(int z=-1;z<=1;z++) for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
        int j=atomic_load_explicit(&heads[gridIndex(cell+int3(x,y,z))],memory_order_relaxed);
        while(j>=0) {
            float3 d=pos-p[j].predicted.xyz;
            float w=u.physics.z*poly6(dot(d,d),h);
            correction+=(velocities[j].xyz-velocity)*w; weight+=w;
            j=next[j];
        }
    }
    velocity+=u.physics.w*correction/max(weight,1.0f);
    float speed=length(velocity);
    if(speed>7) velocity*=7/speed;
    float damping=mix(0.60f,0.999f,smoothstep(0.4f,1.0f,u.viewport.w));
    p[i].velocity=float4(velocity*damping,velocities[i].w);
    p[i].position=p[i].predicted;
}

struct QuadOut { float4 position [[position]]; float2 uv; };
vertex QuadOut labFullscreen(uint id [[vertex_id]]) {
    float2 uv=float2((id<<1)&2,id&2);
    return {float4(uv*float2(2,-2)+float2(-1,1),0,1),uv};
}
struct ParticleOut { float4 position [[position]]; float2 corner; float3 center; float dye; float owner; float radius; };
vertex ParticleOut labParticleVertex(uint id [[vertex_id]], uint instance [[instance_id]],
                                    device const Particle *p [[buffer(0)]], constant Uniforms &u [[buffer(1)]]) {
    const float2 corners[6]={{-1,-1},{1,-1},{1,1},{-1,-1},{1,1},{-1,1}};
    float2 c=corners[id];
    float3 center=p[instance].position.xyz;
    float3 right=float3(u.view[0][0],u.view[1][0],u.view[2][0]);
    float3 up=float3(u.view[0][1],u.view[1][1],u.view[2][1]);
    float fade=p[instance].visual.x>0 ? smoothstep(0.0f,0.30f,u.viewport.w-p[instance].visual.x):1.0f;
    float radius=u.viewport.z*fade;
    float3 world=center+(right*c.x+up*c.y)*radius;
    return {u.viewProjection*float4(world,1),c,center,p[instance].velocity.w,p[instance].position.w,radius};
}
struct DepthOut { float depthColor [[color(0)]]; float depth [[depth(any)]]; };
DepthOut particleDepth(ParticleOut in, constant Uniforms &u, constant Vessel *vessels, device const float *profiles) {
    float r2=dot(in.corner,in.corner);
    if(r2>1) discard_fragment();
    float3 right=float3(u.view[0][0],u.view[1][0],u.view[2][0]);
    float3 up=float3(u.view[0][1],u.view[1][1],u.view[2][1]);
    float3 facing=float3(u.view[0][2],u.view[1][2],u.view[2][2]);
    float3 surface=in.center+(right*in.corner.x+up*in.corner.y+facing*sqrt(1-r2))*in.radius;
    int owner=int(round(in.owner));
    if(owner>=0 && owner<int(max(2u,u.options.z))) {
        constant Vessel &v=vessels[owner];
        float3 local=(v.inverseWorld*float4(surface,1)).xyz;
        if(local.y<0 || (local.y<v.dimensions.x && length(local.xz)>radiusAt(local.y,v,profiles))) discard_fragment();
    }
    float4 clip=u.viewProjection*float4(surface,1);
    float depth=clip.z/clip.w;
    return {depth,depth};
}
fragment DepthOut labParticleDepth(ParticleOut in [[stage_in]], constant Uniforms &u [[buffer(1)]], constant Vessel *v [[buffer(2)]], device const float *profiles [[buffer(3)]]) {
    return particleDepth(in,u,v,profiles);
}
float3 boardColor(float dye) {
    switch(clamp(int(round(dye)),0,11)) {
        case 0:return float3(0.05,0.58,0.86);case 1:return float3(0.96,0.34,0.07);
        case 2:return float3(0.20,0.76,0.36);case 3:return float3(0.94,0.34,0.65);
        case 4:return float3(1.00,0.72,0.08);case 5:return float3(0.98,0.71,0.61);
        case 6:return float3(0.55,0.30,0.95);case 7:return float3(0.12,0.78,0.62);
        case 8:return float3(0.72,0.04,0.24);case 9:return float3(0.08,0.24,0.88);
        case 10:return float3(0.54,0.78,0.06);default:return float3(0.82,0.78,0.68);
    }
}
struct BoardDepthOut { float depthColor [[color(0)]]; float4 frontDye [[color(1)]]; float depth [[depth(any)]]; };
fragment BoardDepthOut labBoardParticleDepth(ParticleOut in [[stage_in]], constant Uniforms &u [[buffer(1)]], constant Vessel *v [[buffer(2)]], device const float *profiles [[buffer(3)]]) {
    DepthOut surface=particleDepth(in,u,v,profiles);
    return {surface.depthColor,float4(boardColor(in.dye),1),surface.depth};
}

fragment float4 labParticleThickness(ParticleOut in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
    float r2=dot(in.corner,in.corner);
    if(r2>1) discard_fragment();
    float thickness=2*in.radius*sqrt(1-r2);
    float3 color=(u.options.w&1u) ? boardColor(in.dye) : mix(float3(0.04,0.69,0.72),float3(1.0,0.45,0.09),in.dye);
    return float4(color*thickness,thickness);
}
kernel void labSmoothDepth(texture2d<float,access::read> source [[texture(0)]], texture2d<float,access::write> target [[texture(1)]],
                           constant uint2 &direction [[buffer(0)]], uint2 id [[thread_position_in_grid]]) {
    if(id.x>=target.get_width() || id.y>=target.get_height()) return;
    float center=source.read(id).x;
    if(center>=0.99999f) { target.write(float4(1),id); return; }
    float sum=0, weights=0;
    for(int k=-7;k<=7;k++) {
        int2 xy=clamp(int2(id)+int2(direction)*k,int2(0),int2(target.get_width()-1,target.get_height()-1));
        float value=source.read(uint2(xy)).x;
        if(value>=0.99999f) continue;
        float distance=(value-center)*1250;
        float w=exp(-float(k*k)/26.0f-distance*distance);
        sum+=value*w; weights+=w;
    }
    target.write(float4(sum/max(weights,0.0001f)),id);
}
kernel void labBoardSmoothDepth(texture2d<float,access::read> source [[texture(0)]], texture2d<float,access::write> target [[texture(1)]],
                           constant uint2 &direction [[buffer(0)]], uint2 id [[thread_position_in_grid]]) {
    if(id.x>=target.get_width() || id.y>=target.get_height()) return;
    float center=source.read(id).x;
    if(center>=0.99999f) { target.write(float4(1),id); return; }
    float sum=0, weights=0;
    for(int k=-10;k<=10;k++) {
        int2 xy=clamp(int2(id)+int2(direction)*k,int2(0),int2(target.get_width()-1,target.get_height()-1));
        float value=source.read(uint2(xy)).x;
        if(value>=0.99999f) continue;
        float distance=(value-center)*700;
        float w=exp(-float(k*k)/48.0f-distance*distance);
        sum+=value*w; weights+=w;
    }
    target.write(float4(sum/max(weights,0.0001f)),id);
}
// Smooth particle-scale color speckles without averaging through separate
// depth surfaces. A narrow transition keeps the two puzzle colors readable.
kernel void labSmoothDye(texture2d<float,access::read> source [[texture(0)]], texture2d<float,access::write> target [[texture(1)]],
                         texture2d<float,access::read> depth [[texture(2)]], constant uint2 &direction [[buffer(0)]], uint2 id [[thread_position_in_grid]]) {
    if(id.x>=target.get_width() || id.y>=target.get_height()) return;
    float3 center=source.read(id).rgb;float d=depth.read(id).x;
    if(center.x<0) { target.write(float4(-1),id);return; }
    float3 sum=0;float weights=0;
    for(int k=-5;k<=5;k++) {
        int2 xy=clamp(int2(id)+int2(direction)*k,int2(0),int2(target.get_width()-1,target.get_height()-1));
        float3 color=source.read(uint2(xy)).rgb;
        if(color.x<0) continue;
        float distance=(depth.read(uint2(xy)).x-d)*800;
        float weight=exp(-float(k*k)/14.0f-distance*distance);
        sum+=color*weight;weights+=weight;
    }
    target.write(float4(sum/max(weights,0.0001f),1),id);
}

float3 worldAt(float2 uv, float depth, constant Uniforms &u) {
    float4 p=u.inverseViewProjection*float4(uv*float2(2,-2)+float2(-1,1),depth,1);
    return p.xyz/p.w;
}
float3 studio(float3 direction) {
    float3 color=mix(float3(0.025,0.045,0.065),float3(0.15,0.23,0.29),smoothstep(-0.2f,0.8f,direction.y));
    float key=pow(max(dot(direction,normalize(float3(-0.7,0.8,1.0))),0.0f),24.0f);
    float edge=pow(max(dot(direction,normalize(float3(1,0.4,-0.6))),0.0f),50.0f);
    float strip=exp(-pow((direction.x+0.46f)*14,2.0f))*smoothstep(-0.25f,0.25f,direction.y)*smoothstep(-0.2f,0.3f,direction.z);
    return color+key*float3(2.0,2.0,1.8)+edge*float3(0.5,1.25,1.6)+strip*float3(0.7,0.85,0.9);
}
float3 background(float2 uv, constant Uniforms &u) {
    float3 origin=u.camera.xyz;
    float3 ray=normalize(worldAt(uv,0.99,u)-origin);
    float3 color=mix(float3(0.004,0.009,0.017),float3(0.012,0.025,0.035),uv.y);
    if(ray.y<0) {
        float t=-origin.y/ray.y;
        float3 p=origin+ray*t;
        float vignette=exp(-dot(p.xz,p.xz)*0.025);
        float shadow=0.35*exp(-dot((p.xz-float2(-1.25,0))*float2(1,1.5),(p.xz-float2(-1.25,0))*float2(1,1.5))*2.2);
        shadow+=0.40*exp(-dot((p.xz-float2(1.1,0))*float2(1,1.5),(p.xz-float2(1.1,0))*float2(1,1.5))*1.8);
        color=mix(color,float3(0.022,0.035,0.045)*(1-shadow),vignette);
        // The board already has contact shadows and no longer needs the large
        // floor ellipse. Retain the smaller marker in the standalone pour
        // study, whose two-vessel composition still uses it for orientation.
        if(!(u.options.w&1u)) {
            float ellipse=length(p.xz/float2(3.05,1.6));
            color+=float3(0.045,0.075,0.087)*exp(-pow((ellipse-1)*110,2.0f));
        }
    }
    return color;
}
fragment float4 labCompose(QuadOut in [[stage_in]], constant Uniforms &u [[buffer(0)]],
                            texture2d<float> depth [[texture(0)]], texture2d<float> thickness [[texture(1)]], texture2d<float> frontDye [[texture(2)]]) {
    constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);
    float2 uv=in.uv, pixel=1/u.viewport.xy;
    float d=depth.sample(s,uv).x;
    float3 bg=background(uv,u);
    if(d>=0.99999) return float4(bg,1);
    float3 p=worldAt(uv,d,u);
    float dl=depth.sample(s,uv-float2(pixel.x,0)).x, dr=depth.sample(s,uv+float2(pixel.x,0)).x;
    float dt=depth.sample(s,uv-float2(0,pixel.y)).x, db=depth.sample(s,uv+float2(0,pixel.y)).x;
    float3 dx=abs(dl-d)<abs(dr-d) ? p-worldAt(uv-float2(pixel.x,0),dl,u) : worldAt(uv+float2(pixel.x,0),dr,u)-p;
    float3 dy=abs(dt-d)<abs(db-d) ? p-worldAt(uv-float2(0,pixel.y),dt,u) : worldAt(uv+float2(0,pixel.y),db,u)-p;
    float3 n=normalize(cross(dx,dy));
    float3 eye=normalize(u.camera.xyz-p);
    if(dot(n,eye)<0) n=-n;
    float4 medium=thickness.sample(s,uv);
    float3 tint=medium.rgb/max(medium.a,0.0001f);
    if (u.options.w&1u) {
        // Shade the nearest fluid identity rather than optically averaging
        // every particle behind it into a muddy third color.
        float3 color=frontDye.sample(s,uv).rgb;
        if (color.x>=0) tint=color;
    }
    float opticalDepth=medium.a*0.55;
    float3 absorption=exp(-(1-tint)*opticalDepth*2.8);
    float3 refracted=background(uv+n.xy*0.016,u);
    float diffuse=0.3+0.7*max(dot(n,normalize(float3(-0.5,1,1))),0.0f);
    float fresnel=0.025+0.975*pow(1-max(dot(n,eye),0.0f),5.0f);
    float3 color=refracted*absorption+tint*((u.options.w&1u) ? float3(1-exp(-opticalDepth*2.0f)):(1-absorption))*diffuse;
    color=mix(color,studio(reflect(-eye,n)),fresnel*0.70);
    float spec=pow(max(dot(reflect(-normalize(float3(-0.6,1,1)),n),eye),0.0f),90.0f);
    color+=float3(0.75,0.95,1)*spec*0.65;
    return float4(color,1);
}
struct GlassOut { float4 position [[position]]; float3 world; float3 normal; float3 local; };
vertex GlassOut labGlassVertex(uint i [[vertex_id]], device const Vertex *vertices [[buffer(0)]],
                              constant Uniforms &u [[buffer(1)]], constant Vessel &v [[buffer(2)]]) {
    float4 world=v.world*vertices[i].position;
    return {u.viewProjection*world,world.xyz,(v.world*vertices[i].normal).xyz,vertices[i].position.xyz};
}
fragment float4 labGlassFragment(GlassOut in [[stage_in]], constant Uniforms &u [[buffer(1)]], constant Vessel &v [[buffer(2)]],
                                texture2d<float> scene [[texture(0)]]) {
    constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);
    float2 uv=in.position.xy/u.viewport.xy;
    float3 n=normalize(in.normal), eye=normalize(u.camera.xyz-in.world);
    if(dot(n,eye)<0) n=-n;
    float fresnel=0.04+0.96*pow(1-max(dot(n,eye),0.0f),5.0f);
    float3 cameraNormal=(u.view*float4(n,0)).xyz;
    float path=v.dimensions.z/max(dot(n,eye),0.18f);
    float2 offset=cameraNormal.xy*float2(1,-1)*min(path*0.10f,0.012f);
    float3 base=scene.sample(s,uv+offset).rgb*exp(-float3(0.38,0.12,0.06)*path);
    float3 reflected=studio(reflect(-eye,n));
    float3 color=mix(base*float3(0.96,0.985,1.0),reflected,0.045+fresnel*0.55);
    float line=0;
    for(int i=0;i<4;i++) line=max(line,1-smoothstep(0.003f,0.011f,abs(in.local.y-v.marks[i])));
    // Volume graduations are restrained short strokes on the front of the glass.
    float front=smoothstep(0.10f,0.3f,in.local.z)*(1-smoothstep(0.06f,0.24f,abs(in.local.x)));
    color=mix(color,float3(0.59,0.79,0.82),line*front*0.48);
    if(v.marks.w<0) {
        float valveY=v.dimensions.x*0.76f;
        float collar=1-smoothstep(0.006f,0.022f,abs(in.local.y-valveY));
        float down=(1-smoothstep(0.010f,0.030f,abs(in.local.x)))*(1-smoothstep(0.0f,0.09f,abs(in.local.y-(valveY-0.07f))));
        color=mix(color,float3(0.12f,0.88f,0.92f),front*max(collar,down)*0.88f);
    }
    float rim=1-smoothstep(0.012f,0.035f,abs(in.local.y-v.dimensions.x));
    color+=rim*float3(0.15,0.22,0.25);
    float foot=1-smoothstep(0.005f,0.055f,abs(in.local.y));
    color+=foot*float3(0.035,0.065,0.075);
    return float4(color,1);
}
fragment float4 labBoardGlassFragment(GlassOut in [[stage_in]], constant Uniforms &u [[buffer(1)]], constant Vessel &v [[buffer(2)]],
                                texture2d<float> scene [[texture(0)]], texture2d<float> liquidDepth [[texture(1)]], constant float &clarity [[buffer(3)]]) {
    constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);
    float2 uv=in.position.xy/u.viewport.xy;
    // Evaluate derivatives before the depth-dependent early return.
    float rimWidth=clamp(fwidth(in.local.y)*1.25f,0.035f,0.08f);
    // A rear glass shell cannot tint liquid already in front of it.
    if(liquidDepth.sample(s,uv).x+0.00001f<in.position.z) return scene.sample(s,uv);
    float3 n=normalize(in.normal), eye=normalize(u.camera.xyz-in.world);
    if(dot(n,eye)<0) n=-n;
    float fresnel=0.04+0.96*pow(1-max(dot(n,eye),0.0f),5.0f);
    float3 cameraNormal=(u.view*float4(n,0)).xyz;
    float path=v.dimensions.z/max(dot(n,eye),0.18f);
    float2 offset=cameraNormal.xy*float2(1,-1)*min(path*0.10f,0.006f)*clarity;
    float3 base=scene.sample(s,uv+offset).rgb*exp(-float3(0.38,0.12,0.06)*path);
    float3 reflected=studio(reflect(-eye,n));
    float3 color=mix(base*float3(0.96,0.985,1.0),reflected,0.045+fresnel*0.55);
    float line=0;
    for(int i=0;i<4;i++) line=max(line,1-smoothstep(0.003f,0.011f,abs(in.local.y-v.marks[i])));
    // Volume graduations are restrained short strokes on the front of the glass.
    float front=smoothstep(0.10f,0.3f,in.local.z)*(1-smoothstep(0.06f,0.24f,abs(in.local.x)));
    color=mix(color,float3(0.59,0.79,0.82),line*front*0.48);
    if(v.marks.w<0) {
        float valveY=v.dimensions.x*0.76f;
        float collar=1-smoothstep(0.006f,0.022f,abs(in.local.y-valveY));
        float down=(1-smoothstep(0.010f,0.030f,abs(in.local.x)))*(1-smoothstep(0.0f,0.09f,abs(in.local.y-(valveY-0.07f))));
        color=mix(color,float3(0.12f,0.88f,0.92f),front*max(collar,down)*0.88f);
    }
    // A broad, neutral edge remains legible without a selection-colored glow.
    // Screen derivatives keep the rim from collapsing into a subpixel hairline.
    float facing=abs(dot(n,eye));
    float silhouette=1-smoothstep(0.12f,0.50f,facing);
    color=mix(color,float3(0.46,0.56,0.60),silhouette*0.72f);
    float rim=1-smoothstep(rimWidth,rimWidth*2,abs(in.local.y-v.dimensions.x));
    color=mix(color,float3(0.64,0.72,0.75),rim*0.78f);
    float foot=1-smoothstep(0.018f,0.085f,abs(in.local.y));
    color=mix(color,float3(0.40,0.49,0.53),foot*0.65f);
    return float4(color,1);
}
fragment float4 labBoardCapFragment(GlassOut in [[stage_in]], constant Uniforms &u [[buffer(1)]],
                                    constant float4 &capColor [[buffer(3)]]) {
    float3 n=normalize(in.normal),eye=normalize(u.camera.xyz-in.world);
    if(dot(n,eye)<0) n=-n;
    float diffuse=0.52+0.48*max(dot(n,normalize(float3(-0.55,0.85,0.75))),0.0f);
    float fresnel=pow(1-max(dot(n,eye),0.0f),4.0f);
    float side=1-smoothstep(0.35f,0.75f,abs(n.y));
    float grooves=0.5f+0.5f*cos(atan2(in.local.z,in.local.x)*48.0f);
    float3 color=capColor.rgb*diffuse*(1-side*grooves*0.12f);
    color+=studio(reflect(-eye,n))*(0.08f+fresnel*0.20f);
    color+=float3(0.30,0.38,0.42)*pow(max(dot(reflect(-normalize(float3(-0.6,1,1)),n),eye),0.0f),70.0f);
    return float4(color,1);
}
fragment float4 labCopy(QuadOut in [[stage_in]], texture2d<float> scene [[texture(0)]]) {
    constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);
    return scene.sample(s,in.uv);
}

struct BoardBand { float4 range; };
kernel void labBoardConstrain(device Particle *p [[buffer(0)]], constant Uniforms &u [[buffer(1)]],
    constant Vessel *v [[buffer(2)]], device const float *profiles [[buffer(3)]], constant BoardBand *bands [[buffer(4)]], uint i [[thread_position_in_grid]]) {
    if(i>=u.options.x || boardFrozen(p[i],u)) return;
    int owner=int(round(p[i].predicted.w));
    if(owner<0 || owner>=int(u.options.z)) return;
    uint parcel=uint(p[i].visual.y),count=uint(u.camera.w);
    if(parcel>=count) return;
    float4 band=bands[owner*count+parcel].range;
    if(band.z<0.5) return;
    float3 local=(v[owner].inverseWorld*float4(p[i].predicted.xyz,1)).xyz;
    // Sorting-mode interfaces travel with the vial. This retains the lower
    // colors while the permitted top parcel remains free to form the stream.
    local.y=clamp(local.y,band.x+0.005f,band.y-0.005f);
    p[i].predicted.xyz=(v[owner].world*float4(local,1)).xyz;
    p[i].predicted=collide(p[i].predicted,v,profiles,u.options.z,true,p[i].visual.z>0.5f);
}

// Two-dimensional optical styling only: sample the rear scene through the moving
// cavity. The foreground particles and hit targets are never displaced.
#include <SwiftUI/SwiftUI_Metal.h>
[[ stitchable ]] half4 labVialLens(float2 position, SwiftUI::Layer layer, float2 base,
                                  float scale, float height, float angle,
                                  device const float *radii, int count) {
    half4 original=layer.sample(position);
    float2 d=(position-base)/max(scale,1.0f);d.y=-d.y;
    float c=cos(angle),s=sin(angle);
    float2 q=float2(c*d.x-s*d.y,s*d.x+c*d.y);
    if(q.y<=0 || q.y>=height || count<2) return original;
    float index=clamp(q.y/height*float(count-1),0.0f,float(count-1));
    int lo=min(count-2,int(index));float radius=mix(radii[lo],radii[lo+1],index-float(lo));
    float edge=abs(q.x)/max(radius,0.01f);
    if(edge>=1) return original;
    float coverage=(1-smoothstep(0.93f,1.0f,edge))*smoothstep(0.0f,0.06f,q.y)*smoothstep(0.0f,0.06f,height-q.y);
    float bend=sign(q.x)*pow(edge,2.0f)*(1-edge)*16.0f;
    float2 offset=float2(c,s)*bend;
    half4 bent=layer.sample(position+offset);
    half4 soft=(bent*half(2)+layer.sample(position+offset+float2(0.7,0))+layer.sample(position+offset-float2(0.7,0)))*half(0.25);
    return mix(original,soft,half(coverage));
}
