import std/osproc
import std/unittest
import std/strutils

func testFileLocation(testname: string): string =
  "tests/" & testname & "/" & testname & ".noro"

func testReturnCodeLocation(testname: string): string =
  "tests/" & testname & "/" & testname & ".ret"

func testOutputLocation(testname: string): string =
  "tests/" & testname & "/" & testname & ".out"

proc expectedTestOutput(testname: string, testStdout= false): (string, int) =
  let expectedRetCode = readFile(testReturnCodeLocation(testname)).parseInt
  if testStdout:
    let expectedStdout = readFile(testOutputLocation(testname))
    return (expectedStdout, expectedRetCode)
  
  return ("", expectedRetCode)

proc runIntegrationTest(testname: string): (string, int) =
  # generate asm file
  var (output, retcode) = osproc.execCmdEx("./noro " & testFileLocation(testname))
  
  assert retcode == 0, "failed to run noro"

  # run assembly script
  (output, retcode) = osproc.execCmdEx("./runasm.sh")
  
  assert retcode == 0, "failed to run assembly script"

  # run compiled program
  (output, retcode) = osproc.execCmdEx("./asm/out")
  
  return (output, retcode)



proc runTest(testname: string, expectStdout = false): bool =
  let (output, exitcode) = runIntegrationTest(testname)
  let (expectedTestOutputStr, expectedRetcodeInt) = expectedTestOutput(testname)
  

  if expectStdout:
    return exitcode == expectedRetcodeInt and expectedTestOutputStr == output
  else:
    return exitcode == expectedRetcodeInt

suite "integration tests":
  # compile main program once before executing tests
  let res = osproc.execCmd("nimble build --multimethods:on")
  if res != 0:
    echo "failed to compile"
    quit(QuitFailure)
  
  setup:
    discard
    
  test "t1":
    check runTest("t1") 
  
  test "t2":
    check runTest("t2")
  
  test "t3":
    check runTest("t3")

  test "t4":
    check runTest("t4")
  
  test "t5":
    check runTest("t5")
