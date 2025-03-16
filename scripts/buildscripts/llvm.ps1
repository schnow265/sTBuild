# Platform detection
$script:IsWindows = $PSVersionTable.PSEdition -eq "Desktop" -or 
                   ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows)
$script:IsLinux = $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
$script:IsMacOS = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS

$script:HomeDir = if ($script:IsWindows) { $env:USERPROFILE } else { $env:HOME }

function _Get-LLVMCMakeCommand {
    [CmdletBinding()]
    param(
        # Basic configuration
        [string]$InstallDir,
        [string]$BuildType,
        [string]$LLvmProjects,
        [string]$llvmRuntimes,
        [string]$llvmTargets,

        # Compiler options
        [string]$CompilerArgs,
        [int]$ParallelCompileJobs,
        [int]$ParallelLinkJobs,
        [string]$LinkerFlags,
        [string]$AsmFlags,
        
        # Core build options
        [bool]$EnableAssertions,
        [bool]$OptimizedTableGen,
        [bool]$StaticBuild,
        [bool]$EnablePIC,
        [bool]$UseLibcxx,
        
        # Components and features
        [bool]$EnableZlib,
        [bool]$EnableLibXml2,
        [bool]$EnableTerminfo,
        [bool]$EnableLibedit,
        [bool]$EnableBindings,
        [bool]$EnableLLD,
        [bool]$UseGold,
        [bool]$EnableZ3,
        [bool]$EnableBacktraceLib,
        [bool]$EnableDocs,
        [bool]$EnableDoxygen,
        [bool]$EnableSphinx,
        [bool]$EnableThreadSanitizer,
        [bool]$EnableAddressSanitizer,
        [bool]$EnableUndefinedBehaviorSanitizer,
        [bool]$EnableMemorySanitizer,
        [bool]$EnableDataFlowSanitizer,
        [bool]$EnableLibFuzzer,
        [bool]$ExperimentalCoroutines,
        [bool]$EnableJIT,
        [bool]$EnableCCache,
        
        # Testing options
        [bool]$BuildTests,
        [bool]$BuildExamples,
        [bool]$BuildBenchmarks,
        
        # Language options
        [bool]$EnableObjC,
        [bool]$EnableCXX,
        
        # Plugin options
        [bool]$EnablePlugins,
        [string]$PluginsToLoad,
        
        # Advanced options
        [string]$HostTriple,
        [string]$TargetTriple,
        [bool]$EnableWerror,
        [bool]$EnableLTO,
        [bool]$EnableModules,
        [bool]$EnableIROptimizer,
        [bool]$EnableBitcodeFile,
        [bool]$UseNewPassManager
    )

    # Platform-specific compiler flags
    $platformCompilerFlags = if ($script:IsWindows) {
        $CompilerArgs  # Windows uses /O2, etc.
    } else {
        "-O2"  # Linux/macOS uses -O2, etc.
    }

    $cmakeCommand = @(
        "cmake -S llvm-project\llvm -B build -G ""Ninja"""
        "-DCMAKE_BUILD_TYPE=$BuildType"
        "-DCMAKE_INSTALL_PREFIX=""$InstallDir"""
        "-DLLVM_ENABLE_PROJECTS=""$LLvmProjects"""
        "-DLLVM_ENABLE_RUNTIMES=""$llvmRuntimes"""
        "-DLLVM_TARGETS_TO_BUILD=""$llvmTargets"""
    )

    # Add platform-specific compiler flags
    if ($script:IsWindows) {
        $cmakeCommand += "-DCMAKE_CXX_FLAGS=""$platformCompilerFlags"""
        $cmakeCommand += "-DCMAKE_C_FLAGS=""$platformCompilerFlags"""
    } else {
        $cmakeCommand += "-DCMAKE_CXX_FLAGS=""$platformCompilerFlags"""
        $cmakeCommand += "-DCMAKE_C_FLAGS=""$platformCompilerFlags"""
    }

    $cmakeCommand += "-DBUILD_SHARED_LIBS=OFF"

    if ($AsmFlags) { $cmakeCommand += "-DCMAKE_ASM_FLAGS=""$AsmFlags""" }
    if ($LinkerFlags) { 
        $cmakeCommand += "-DCMAKE_EXE_LINKER_FLAGS=""$LinkerFlags"""
        $cmakeCommand += "-DCMAKE_SHARED_LINKER_FLAGS=""$LinkerFlags"""
        $cmakeCommand += "-DCMAKE_MODULE_LINKER_FLAGS=""$LinkerFlags"""
    }

    $cmakeCommand += "-DLLVM_PARALLEL_COMPILE_JOBS=""$ParallelCompileJobs"""
    $cmakeCommand += "-DLLVM_PARALLEL_LINK_JOBS=""$ParallelLinkJobs"""
    $cmakeCommand += "-DLLVM_ENABLE_ASSERTIONS=$(if ($EnableAssertions) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_OPTIMIZED_TABLEGEN=$(if ($OptimizedTableGen) { "ON" } else { "OFF" })"
    
    $cmakeCommand += "-DLLVM_BUILD_STATIC=$(if ($StaticBuild) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_PIC=$(if ($EnablePIC) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_LIBCXX=$(if ($UseLibcxx) { "ON" } else { "OFF" })"
    
    $cmakeCommand += "-DLLVM_ENABLE_ZLIB=$(if ($EnableZlib) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_LIBXML2=$(if ($EnableLibXml2) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_TERMINFO=$(if ($EnableTerminfo) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_LIBEDIT=$(if ($EnableLibedit) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_BINDINGS=$(if ($EnableBindings) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_LLD=$(if ($EnableLLD) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_USE_LINKER=$(if ($UseGold) { "gold" } elseif ($EnableLLD) { "lld" } else { "default" })"
    $cmakeCommand += "-DLLVM_ENABLE_Z3_SOLVER=$(if ($EnableZ3) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_LIBBACKTRACE=$(if ($EnableBacktraceLib) { "ON" } else { "OFF" })"
    
    $cmakeCommand += "-DLLVM_INCLUDE_DOCS=$(if ($EnableDocs) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_DOXYGEN=$(if ($EnableDoxygen) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_SPHINX=$(if ($EnableSphinx) { "ON" } else { "OFF" })"
    
    $cmakeCommand += "-DLLVM_BUILD_TESTS=$(if ($BuildTests) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_BUILD_EXAMPLES=$(if ($BuildExamples) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_BUILD_BENCHMARKS=$(if ($BuildBenchmarks) { "ON" } else { "OFF" })"
    
    $cmakeCommand += "-DLLVM_ENABLE_THREADS=ON"
    $cmakeCommand += "-DLLVM_ENABLE_UNWIND_TABLES=ON"
    $cmakeCommand += "-DLLVM_ENABLE_EXPENSIVE_CHECKS=OFF"
    
    $cmakeCommand += "-DLLVM_ENABLE_THREAD_SANITIZER=$(if ($EnableThreadSanitizer) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_ADDRESS_SANITIZER=$(if ($EnableAddressSanitizer) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_UNDEFINED_BEHAVIOR_SANITIZER=$(if ($EnableUndefinedBehaviorSanitizer) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_MEMORY_SANITIZER=$(if ($EnableMemorySanitizer) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_DATAFLOW_SANITIZER=$(if ($EnableDataFlowSanitizer) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_LIBFUZZER=$(if ($EnableLibFuzzer) { "ON" } else { "OFF" })"
    
    $cmakeCommand += "-DLLVM_ENABLE_EH=$(if ($ExperimentalCoroutines) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_COROUTINES=$(if ($ExperimentalCoroutines) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_JIT=$(if ($EnableJIT) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_CCACHE=$(if ($EnableCCache) { "ON" } else { "OFF" })"
    
    $cmakeCommand += "-DLLVM_INCLUDE_TOOLS=ON"
    $cmakeCommand += "-DLLVM_INCLUDE_UTILS=ON"
    $cmakeCommand += "-DLLVM_INSTALL_UTILS=ON"
    
    $cmakeCommand += "-DLLVM_ENABLE_OBJC_ARC=$(if ($EnableObjC) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_CXX=$(if ($EnableCXX) { "ON" } else { "OFF" })"
    
    $cmakeCommand += "-DLLVM_ENABLE_PLUGINS=$(if ($EnablePlugins) { "ON" } else { "OFF" })"
    if ($PluginsToLoad) {
        $cmakeCommand += "-DLLVM_PLUGINS_TO_LOAD=""$PluginsToLoad"""
    }
    
    if ($HostTriple) {
        $cmakeCommand += "-DLLVM_HOST_TRIPLE=""$HostTriple"""
    }
    if ($TargetTriple) {
        $cmakeCommand += "-DLLVM_DEFAULT_TARGET_TRIPLE=""$TargetTriple"""
    }
    
    $cmakeCommand += "-DLLVM_ENABLE_WERROR=$(if ($EnableWerror) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_LTO=$(if ($EnableLTO) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_MODULES=$(if ($EnableModules) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_IR_OPTIMIZER=$(if ($EnableIROptimizer) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_ENABLE_DUMP=ON"
    $cmakeCommand += "-DLLVM_ENABLE_BITCODE_FILE=$(if ($EnableBitcodeFile) { "ON" } else { "OFF" })"
    $cmakeCommand += "-DLLVM_USE_NEWPM=$(if ($UseNewPassManager) { "ON" } else { "OFF" })"

    return $cmakeCommand -join ' `' + "`n    "
}

function sTBuild-LLVM {
    [CmdletBinding()]
    param (
        # Basic configuration
        [Parameter(HelpMessage="Directory to install LLVM")]
        [string]$InstallDir = $(Join-Path $script:HomeDir "sTBuild\llvm\temp"),
        
        [Parameter(HelpMessage="URL of the LLVM Git repository")]
        [string]$LLVMRemote = "https://github.com/llvm/llvm-project.git",
        
        [Parameter(HelpMessage="Build type (Debug, Release, RelWithDebInfo, or MinSizeRel)")]
        [string]$BuildType = "Release",
        
        [Parameter(HelpMessage="LLVM projects to build (e.g., 'clang;lld;compiler-rt' or 'all')")]
        [string]$LLvmProjects = "all",
        
        [Parameter(HelpMessage="LLVM runtimes to build (e.g., 'libcxx;libcxxabi;libc')")]
        [string]$llvmRuntimes = "libc",
        
        [Parameter(HelpMessage="Target architectures (e.g., 'X86;ARM;AArch64')")]
        [string]$llvmTargets = "X86",

        # Compiler options
        [Parameter(HelpMessage="Compiler flags to use during build")]
        [string]$CompilerArgs = $(if ($script:IsWindows) { "/O2" } else { "-O2" }),
        
        [Parameter(HelpMessage="Number of parallel compilation jobs")]
        [int]$ParallelCompileJobs = $env:NUMBER_OF_PROCESSORS,
        
        [Parameter(HelpMessage="Number of parallel link jobs")]
        [int]$ParallelLinkJobs = $env:NUMBER_OF_PROCESSORS,
        
        # Core build options
        [Parameter(HelpMessage="Enable internal assertions in LLVM")]
        [switch]$EnableAssertions = $false,
        
        [Parameter(HelpMessage="Build optimized TableGen for faster build times")]
        [switch]$OptimizedTableGen = $true,
        
        [Parameter(HelpMessage="Build LLVM as static libraries")]
        [switch]$StaticBuild = $false,
        
        [Parameter(HelpMessage="Enable Position Independent Code")]
        [switch]$EnablePIC = $true,
        
        [Parameter(HelpMessage="Use libc++ instead of the system's C++ standard library")]
        [switch]$UseLibcxx = $false,
        
        [Parameter(HelpMessage="Additional linker flags for the build")]
        [string]$LinkerFlags = "",
        
        [Parameter(HelpMessage="Assembly flags for the build")]
        [string]$AsmFlags = "",
        
        # Components and features
        [Parameter(HelpMessage="Enable zlib compression support")]
        [switch]$EnableZlib = $true,
        
        [Parameter(HelpMessage="Enable libxml2 support")]
        [switch]$EnableLibXml2 = $true,
        
        [Parameter(HelpMessage="Enable terminal manipulation library support")]
        [switch]$EnableTerminfo = $true,
        
        [Parameter(HelpMessage="Enable command line editing library support")]
        [switch]$EnableLibedit = $true,
        
        [Parameter(HelpMessage="Build language bindings (e.g., for Python)")]
        [switch]$EnableBindings = $true,
        
        [Parameter(HelpMessage="Use LLVM's linker (LLD) during build")]
        [switch]$EnableLLD = $false,
        
        [Parameter(HelpMessage="Use Gold linker during build")]
        [switch]$UseGold = $false,
        
        [Parameter(HelpMessage="Enable Z3 constraint solver for static analysis")]
        [switch]$EnableZ3 = $false,
        
        [Parameter(HelpMessage="Enable backtrace library for improved stack traces")]
        [switch]$EnableBacktraceLib = $false,
        
        [Parameter(HelpMessage="Build LLVM documentation")]
        [switch]$EnableDocs = $false,
        
        [Parameter(HelpMessage="Enable Doxygen documentation generation")]
        [switch]$EnableDoxygen = $false,
        
        [Parameter(HelpMessage="Enable Sphinx documentation generation")]
        [switch]$EnableSphinx = $false,
        
        [Parameter(HelpMessage="Enable Thread Sanitizer for detecting threading bugs")]
        [switch]$EnableThreadSanitizer = $false,
        
        [Parameter(HelpMessage="Enable Address Sanitizer for detecting memory errors")]
        [switch]$EnableAddressSanitizer = $false,
        
        [Parameter(HelpMessage="Enable Undefined Behavior Sanitizer")]
        [switch]$EnableUndefinedBehaviorSanitizer = $false,
        
        [Parameter(HelpMessage="Enable Memory Sanitizer for detecting uninitialized reads")]
        [switch]$EnableMemorySanitizer = $false,
        
        [Parameter(HelpMessage="Enable DataFlow Sanitizer for detecting data flow issues")]
        [switch]$EnableDataFlowSanitizer = $false,
        
        [Parameter(HelpMessage="Enable LibFuzzer for fuzzing LLVM code")]
        [switch]$EnableLibFuzzer = $false,
        
        [Parameter(HelpMessage="Enable experimental coroutines support")]
        [switch]$ExperimentalCoroutines = $false,
        
        [Parameter(HelpMessage="Build with Just-In-Time compilation support")]
        [switch]$EnableJIT = $true,
        
        [Parameter(HelpMessage="Enable CCache to speed up repeated builds")]
        [switch]$EnableCCache = $false,
        
        # Testing options
        [Parameter(HelpMessage="Build LLVM test suite")]
        [switch]$BuildTests = $false,
        
        [Parameter(HelpMessage="Build LLVM examples")]
        [switch]$BuildExamples = $false,
        
        [Parameter(HelpMessage="Build LLVM benchmarks")]
        [switch]$BuildBenchmarks = $false,
        
        # Debugging options
        [Parameter(HelpMessage="Include debug info in runtime libraries")]
        [switch]$EnableDebugRuntime = $false,
        
        [Parameter(HelpMessage="Include debug symbols in binaries")]
        [switch]$EnableDebugSymbols = $false,
        
        [Parameter(HelpMessage="Build with profiling information")]
        [switch]$EnableProfiling = $false,
        
        [Parameter(HelpMessage="Enable code coverage instrumentation")]
        [switch]$EnableCoverage = $false,
        
        # Language options
        [Parameter(HelpMessage="Enable Objective-C support")]
        [switch]$EnableObjC = $false,
        
        [Parameter(HelpMessage="Enable C++ support")]
        [switch]$EnableCXX = $true,
        
        # Plugin options
        [Parameter(HelpMessage="Enable plugin support for LLVM")]
        [switch]$EnablePlugins = $false,
        
        [Parameter(HelpMessage="Comma-separated list of plugins to load")]
        [string]$PluginsToLoad = "",
        
        # Advanced options
        [Parameter(HelpMessage="Specify the host triple for the compiler")]
        [string]$HostTriple = "",
        
        [Parameter(HelpMessage="Specify the default target triple")]
        [string]$TargetTriple = "",
        
        [Parameter(HelpMessage="Treat compiler warnings as errors")]
        [switch]$EnableWerror = $false,
        
        [Parameter(HelpMessage="Enable Link Time Optimization")]
        [switch]$EnableLTO = $false,
        
        [Parameter(HelpMessage="Enable Clang modules for faster compilation")]
        [switch]$EnableModules = $false,
        
        [Parameter(HelpMessage="Enable the IR optimizer")]
        [switch]$EnableIROptimizer = $false,
        
        [Parameter(HelpMessage="Enable writing bitcode files")]
        [switch]$EnableBitcodeFile = $true,
        
        [Parameter(HelpMessage="Use LLVM's new pass manager")]
        [switch]$UseNewPassManager = $true
    )

    # Ensure script stops on any error
    $ErrorActionPreference = "Stop"

    if (Test-Path "$InstallDir\git-hash.txt") {
        $oldBuildHash = Get-Content "$InstallDir\git-hash.txt"
    } else {
        $oldBuildHash = ""
    }

    if (!(test-path "hash.lock")) {
        # Check if llvm-project directory exists
        if (Test-Path "llvm-project") {
            Write-Host -ForegroundColor Cyan "llvm-project directory exists. Updating repository..."
            Set-Location "llvm-project"
            
            # Get the current git commit hash before pull
            $oldHash = git rev-parse HEAD
            
            # Pull latest changes
            git pull
            
            # Get the new git commit hash after pull
            $newHash = git rev-parse HEAD
            
            Set-Location ..
            
            # Check if git hash has changed
            $rebuildNeeded = $oldHash -ne $newHash
            
            if ($rebuildNeeded) {
                Write-Host -ForegroundColor Yellow "Git hash changed from $oldHash to $newHash. Rebuild required."
            } else {
                Write-Host -ForegroundColor Green "Git hash unchanged ($oldHash). No rebuild needed."
            }
        } else {
            Write-Host -ForegroundColor Cyan "Cloning llvm-project repository..."
            git clone "$LLVMRemote" "llvm-project"
            
            # New clone always needs a build
            $rebuildNeeded = $true
        }

        # Remove existing build directory if it exists and rebuild is needed
        if ((Test-Path "build") -and $rebuildNeeded) {
            Write-Host -ForegroundColor Cyan "Removing existing build directory..."
            Remove-Item -Recurse -Force "build"
        }

        if ($oldBuildHash -ne "" -and $oldBuildHash -ne $newHash) {
            Write-Host -ForegroundColor Cyan "Removing existing install directory from hash '$oldBuildHash' ..."
            Remove-Item -Recurse -Force $InstallDir
        }

        Write-Host -ForegroundColor Cyan "Configuring the build with CMake..."
        
        # Create parameter hashtable for splatting
        $cmakeParams = @{
            # Basic configuration
            InstallDir     = $InstallDir
            BuildType      = $BuildType
            LLvmProjects   = $LLvmProjects
            llvmRuntimes   = $llvmRuntimes
            llvmTargets    = $llvmTargets

            # Compiler options
            CompilerArgs        = $CompilerArgs
            ParallelCompileJobs = $ParallelCompileJobs
            ParallelLinkJobs    = $ParallelLinkJobs
            LinkerFlags         = $LinkerFlags
            AsmFlags            = $AsmFlags
            
            # Core build options
            EnableAssertions  = $EnableAssertions
            OptimizedTableGen = $OptimizedTableGen
            StaticBuild       = $StaticBuild
            EnablePIC         = $EnablePIC
            UseLibcxx         = $UseLibcxx
            
            # Components and features
            EnableZlib                        = $EnableZlib
            EnableLibXml2                     = $EnableLibXml2
            EnableTerminfo                    = $EnableTerminfo
            EnableLibedit                     = $EnableLibedit
            EnableBindings                    = $EnableBindings
            EnableLLD                         = $EnableLLD
            UseGold                           = $UseGold
            EnableZ3                          = $EnableZ3
            EnableBacktraceLib                = $EnableBacktraceLib
            EnableDocs                        = $EnableDocs
            EnableDoxygen                     = $EnableDoxygen
            EnableSphinx                      = $EnableSphinx
            EnableThreadSanitizer             = $EnableThreadSanitizer
            EnableAddressSanitizer            = $EnableAddressSanitizer
            EnableUndefinedBehaviorSanitizer  = $EnableUndefinedBehaviorSanitizer
            EnableMemorySanitizer             = $EnableMemorySanitizer
            EnableDataFlowSanitizer           = $EnableDataFlowSanitizer
            EnableLibFuzzer                   = $EnableLibFuzzer
            ExperimentalCoroutines            = $ExperimentalCoroutines
            EnableJIT                         = $EnableJIT
            EnableCCache                      = $EnableCCache
            
            # Testing options
            BuildTests       = $BuildTests
            BuildExamples    = $BuildExamples
            BuildBenchmarks  = $BuildBenchmarks
            
            # Language options
            EnableObjC     = $EnableObjC
            EnableCXX      = $EnableCXX
            
            # Plugin options
            EnablePlugins  = $EnablePlugins
            PluginsToLoad  = $PluginsToLoad
            
            # Advanced options
            HostTriple           = $HostTriple
            TargetTriple         = $TargetTriple
            EnableWerror         = $EnableWerror
            EnableLTO            = $EnableLTO
            EnableModules        = $EnableModules
            EnableIROptimizer    = $EnableIROptimizer
            EnableBitcodeFile    = $EnableBitcodeFile
            UseNewPassManager    = $UseNewPassManager
        }
        
        # Generate cmake command using private function with splatting
        $cmakeCommand = _Get-LLVMCMakeCommand @cmakeParams

        if (Test-Path -Path "cmake-command.txt") { Remove-Item -Path "cmake-command.txt" -Force }
        _Get-LLVMCMakeCommand @cmakeParams > "cmake-command.txt"

        # Execute the generated command
        Invoke-Expression $cmakeCommand

        Write-Host -ForegroundColor Cyan "Building and installing LLVM..."

        Write-Output "$newHash" > "hash.lock"
    } else {
        Write-Host -ForegroundColor Green "In progress build detected. Skipping codebase update & clean rebuild."
    }

    # Cross-platform build command
    if ($script:IsWindows) {
        ninja -C .\build\ install
    } else {
        ninja -C ./build/ install
    }

    Remove-Item -Force "hash.lock"

    Write-Output "$newHash" > "$InstallDir\git-hash.txt"
}

# Create an alias for backward compatibility
New-Alias -Name Build-LLVM -Value sTBuild-LLVM