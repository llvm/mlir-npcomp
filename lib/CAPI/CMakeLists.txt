set(LLVM_LINK_COMPONENTS
  Core
  Support
  nativecodegen
  )

add_npcomp_library(NPCOMPCAPI
  InitLLVM.cpp
  Registration.cpp
  BasicpyTypes.cpp
  NumpyTypes.cpp
  TorchTypes.cpp

  LINK_LIBS PUBLIC
  MLIRExecutionEngine
  MLIRLLVMIR
  MLIRTargetLLVMIRExport
  NPCOMPInitAll
  NPCOMPBasicpyDialect
  NPCOMPNumpyDialect
  NPCOMPTorchDialect
  )
