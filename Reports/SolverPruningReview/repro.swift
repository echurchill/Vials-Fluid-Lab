import Foundation
@main struct PruneReview {
 static func main() {
  let board=[Vial(fluids:[.ember,.ember],capacity:2),Vial(fluids:[],capacity:3),Vial(fluids:[.tide,.ember,.tide],capacity:3)]
  print("canSolve:",VialLevelGenerator.canSolve(board,nodeLimit:10000,depthLimit:30))
  print("minimumMoves:",VialLevelGenerator.minimumMoveCount(board,nodeLimit:10000) as Any)
  print("hint:",VialLevelGenerator.hint(vials:board,helperBeaker:nil,nodeLimit:10000))
 }
}
