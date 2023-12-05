import std/osproc
import std/unittest
import std/strutils

func testFileLocation(testname: string): string =
  "tests/" & testname & "/" & testname & ".noro"

func testOutputLocation(testname: string): string =
  "tests/" & testname & "/" & testname & ".out"

proc expectedTestOutput(testname: string): int =
  readFile(testOutputLocation(testname)).parseInt

proc runIntegrationTestForRetCode(testname: string): (string, int) =
  # generate asm file
  var (output, retcode) = osproc.execCmdEx("./noro " & testFileLocation(testname))
  
  assert retcode == 0, "failed to run noro"

  # assemble asm file
  (output, retcode) = osproc.execCmdEx("nasm -f elf64 asm/out.asm")

  assert retcode == 0, "nasm failed"

  # link asm file
  (output, retcode) = osproc.execCmdEx("ld -o asm/out asm/out.o")

  assert retcode == 0, "ld failed"

  # run executable
  (output, retcode) = osproc.execCmdEx("./asm/out")


  return (output, retcode)



proc runTest(testname: string): bool =
  let (_, exitcode) = runIntegrationTestForRetCode(testname)
  let expectedRetcode = expectedTestOutput(testname)
  result = expectedRetcode == exitcode

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
  
