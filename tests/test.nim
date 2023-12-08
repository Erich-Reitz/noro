import std/osproc
import std/unittest
import std/strutils

func testFileLocation(testname: string): string =
  "tests/" & testname & "/" & testname & ".noro"

func testReturnCodeLocation(testname: string): string =
  "tests/" & testname & "/" & testname & ".ret"

func testOutputLocation(testname: string): string =
  "tests/" & testname & "/" & testname & ".out"

func testExpectedErrorLocation(testname: string): string =
  "tests/" & testname & "/" & testname & ".expected_error"

proc expectedErrorMessage(testname: string): string =
  readFile(testExpectedErrorLocation(testname))

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



proc runTestOfGeneratedExecutable(testname: string, expectStdout = false): bool =
  let (output, exitcode) = runIntegrationTest(testname)
  let (expectedTestOutputStr, expectedRetcodeInt) = expectedTestOutput(testname, expectStdout)
  

  if expectStdout:
    return exitcode == expectedRetcodeInt and expectedTestOutputStr == output
  else:
    return exitcode == expectedRetcodeInt

proc runTestOfCompilerErrorChecking(testname: string): bool =
  let expectedErrorMsg = expectedErrorMessage(testname) 
  let testFileLoc = testFileLocation(testname)

  var (output, exitcode) = osproc.execCmdEx("./noro " & testFileLoc)
  # want a non-zero exit code bc error
  if exitcode == 0:
    return false

  return output == expectedErrorMsg
  

suite "integration tests":
  # compile main program once before executing tests
  let res = osproc.execCmd("nimble build --multimethods:on")
  if res != 0:
    echo "failed to compile"
    quit(QuitFailure)
  
  setup:
    discard
    
  test "t1":
    check runTestOfGeneratedExecutable("t1") 
  
  test "t2":
    check runTestOfGeneratedExecutable("t2")
  
  test "t3":
    check runTestOfGeneratedExecutable("t3")

  test "fibonacci":
    check runTestOfGeneratedExecutable("fibonacci", true)
  
  test "t5":
    check runTestOfGeneratedExecutable("t5", true)

  test "const_reassign":
    check runTestOfCompilerErrorChecking("const_reassign")

  test "multiple_type_specifiers":
    check runTestOfCompilerErrorChecking("multiple_type_specifiers")
  
  test "undeclared_var":
    check runTestOfCompilerErrorChecking("undeclared_var")

  test "wrong_num_args":
    check runTestOfCompilerErrorChecking("wrong_num_args")

  test "return_type_type_error":
    check runTestOfCompilerErrorChecking("return_type_type_error")
  
  test "return_types_are_enforced":
    check runTestOfCompilerErrorChecking("return_types_are_enforced")

  test "six_param_max":
    check runTestOfGeneratedExecutable("six_param_max")