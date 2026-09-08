# Tester protocol

1. Open **Vials Fluid Lab** using the teal pouring-vial icon. Choose **First sort**, **Classic**, **Quick**, then Reset. Solve it using Hint when useful. Note clarity of colors, ease of selection and whether each turn feels too slow or rushed.
2. Reset and repeat in **Fluid / Quick**. Compare the same moves. Watch the stream entering the receiving mouth and the transition from settled pour to returning vial.
3. Between moves, switch presentation. The stacks, move count and undo must remain intact. Try Undo, change puzzles and return, then quit/relaunch after a completed move.
4. Repeat one puzzle in **Relaxed**. Which pace would you choose for everyday play? Which visual style makes the puzzle easier to read, and which is more satisfying?
5. For a short performance sample, open Board diagnostics, choose **Record session**, play normally for about 90 seconds, then **Finish measurement** and **Share measurements**. Repeat at the same pace in the other presentation. Keep brightness, orientation and other workload consistent. Avoid Slow motion and Show particles for this comparison.

For battery evaluation, use an unplugged iPad with comfortable fixed brightness and enough charge below full to observe changes. Record equal play periods, preferably 15–20 minutes per presentation, repeating in reversed order after the device cools. Record start/end charge, elapsed play, thermal state and any perceived warmth. Percentage readings are coarse; a single short run cannot establish battery life. Do not disable the screen lock merely to run a test unattended; the automated trial stops on application suspension. Finish manual recordings before locking the device; move durations include elapsed wall time, including pauses.

## Developer trial hook

The launch arguments `--lab-trial --presentation fluid --pace quick --seconds 90` repeatedly solve First sort and reset it, without changing saved player progress. Use `classic` for the matched run. On Mac, add `--exit-after-trial` to exit after writing the result. Launch through Launch Services (`open -n … --args …`) so the app gets a window; directly executing a second app process can leave it idle without a scene.

Reports are in the app's Documents/FluidLabReports directory. An unfinished move at the trial deadline is excluded from the successful-move count. The trial pauses the board at completion; relaunch normally to play.
