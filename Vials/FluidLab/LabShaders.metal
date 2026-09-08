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
constant uint gridCount = 64*48*32;

float radiusAt(float y, constant Vessel &v, device const float *profiles) {
    float f = clamp(y / v.dimensions.x, 0.0f, 1.0f) * 127;
    uint i = min(uint(f),126u), offset = uint(v.dimensions.y)*128;
    return mix(profiles[offset+i], profiles[offset+i+1], f-float(i));
}
int3 gridCell(float3 p, float h) { return int3(floor((p+float3(4,0.4,2.6))/0.20f)); }
uint gridIndex(int3 c) { c=clamp(c,int3(0),int3(63,47,31)); return uint(c.x+64*(c.y+48*c.z)); }
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

float4 collide(float4 point, constant Vessel *vessels, device const float *profiles) {
    float3 p=point.xyz;
    int owner=int(round(point.w));
    const float margin=0.034;
    if (owner>=0 && owner<2) {
        constant Vessel &v=vessels[owner];
        float3 local=(v.inverseWorld*float4(p,1)).xyz;
        if (local.y>v.dimensions.x+margin) owner=-1;
        else {
            local.y=max(local.y,margin);
            float r=radiusAt(local.y,v,profiles)-margin;
            float radial=length(local.xz);
            if (radial>r) local.xz*=max(r,0.01f)/max(radial,0.0001f);
            p=(v.world*float4(local,1)).xyz;
        }
    }
    if (owner<0) {
        for (int i=0;i<2;i++) {
            constant Vessel &v=vessels[i];
            float3 local=(v.inverseWorld*float4(p,1)).xyz;
            float r=radiusAt(local.y,v,profiles);
            float radial=length(local.xz);
            if (local.y<=v.dimensions.x+margin && local.y>v.dimensions.x-0.26 && radial<r-margin*0.5) {
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
    p.xz=clamp(p.xz,float2(-3.7,-2.35),float2(3.7,2.35));
    return float4(p,float(owner));
}

kernel void labPredict(device Particle *p [[buffer(0)]], constant Uniforms &u [[buffer(1)]],
                       constant Vessel *v [[buffer(2)]], device const float *profiles [[buffer(3)]], uint i [[thread_position_in_grid]]) {
    if (i>=u.options.x) return;
    float3 velocity=p[i].velocity.xyz;
    velocity.y-=9.81f*u.physics.x;
    float speed=length(velocity);
    if (speed>7) velocity*=7/speed;
    p[i].predicted=collide(float4(p[i].position.xyz+velocity*u.physics.x,p[i].position.w),v,profiles);
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
    if(i>=u.options.x) return;
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
    if(i<u.options.x) p[i].predicted=collide(p[i].predicted+deltas[i],v,profiles);
}
kernel void labVelocity(device const Particle *p [[buffer(0)]], constant Uniforms &u [[buffer(1)]],
                        constant Vessel *vessels [[buffer(2)]], device const float *profiles [[buffer(3)]],
                        device float4 *velocities [[buffer(4)]], uint i [[thread_position_in_grid]]) {
    if(i>=u.options.x) return;
    float3 velocity=(p[i].predicted.xyz-p[i].position.xyz)/u.physics.x;
    int owner=int(round(p[i].predicted.w));
    if(owner>=0 && owner<2) {
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
fragment DepthOut labParticleDepth(ParticleOut in [[stage_in]], constant Uniforms &u [[buffer(1)]], constant Vessel *vessels [[buffer(2)]], device const float *profiles [[buffer(3)]]) {
    float r2=dot(in.corner,in.corner);
    if(r2>1) discard_fragment();
    float3 right=float3(u.view[0][0],u.view[1][0],u.view[2][0]);
    float3 up=float3(u.view[0][1],u.view[1][1],u.view[2][1]);
    float3 facing=float3(u.view[0][2],u.view[1][2],u.view[2][2]);
    float3 surface=in.center+(right*in.corner.x+up*in.corner.y+facing*sqrt(1-r2))*in.radius;
    int owner=int(round(in.owner));
    if(owner>=0 && owner<2) {
        constant Vessel &v=vessels[owner];
        float3 local=(v.inverseWorld*float4(surface,1)).xyz;
        if(local.y<0 || (local.y<v.dimensions.x && length(local.xz)>radiusAt(local.y,v,profiles))) discard_fragment();
    }
    float4 clip=u.viewProjection*float4(surface,1);
    float depth=clip.z/clip.w;
    return {depth,depth};
}
fragment float4 labParticleThickness(ParticleOut in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
    float r2=dot(in.corner,in.corner);
    if(r2>1) discard_fragment();
    float thickness=2*in.radius*sqrt(1-r2);
    float3 color=mix(float3(0.04,0.69,0.72),float3(1.0,0.45,0.09),in.dye);
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
        float ellipse=length(p.xz/float2(3.05,1.6));
        color+=float3(0.045,0.075,0.087)*exp(-pow((ellipse-1)*110,2.0f));
    }
    return color;
}
fragment float4 labCompose(QuadOut in [[stage_in]], constant Uniforms &u [[buffer(0)]],
                            texture2d<float> depth [[texture(0)]], texture2d<float> thickness [[texture(1)]]) {
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
    float opticalDepth=medium.a*0.55;
    float3 absorption=exp(-(1-tint)*opticalDepth*2.8);
    float3 refracted=background(uv+n.xy*0.016,u);
    float diffuse=0.3+0.7*max(dot(n,normalize(float3(-0.5,1,1))),0.0f);
    float fresnel=0.025+0.975*pow(1-max(dot(n,eye),0.0f),5.0f);
    float3 color=refracted*absorption+tint*(1-absorption)*diffuse;
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
    float rim=1-smoothstep(0.012f,0.035f,abs(in.local.y-v.dimensions.x));
    color+=rim*float3(0.15,0.22,0.25);
    float foot=1-smoothstep(0.005f,0.055f,abs(in.local.y));
    color+=foot*float3(0.035,0.065,0.075);
    return float4(color,1);
}
fragment float4 labCopy(QuadOut in [[stage_in]], texture2d<float> scene [[texture(0)]]) {
    constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);
    return scene.sample(s,in.uv);
}
