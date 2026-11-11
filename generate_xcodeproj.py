import os
import hashlib

def make_uuid(seed: str) -> str:
    h = hashlib.md5(seed.encode('utf-8')).hexdigest()[:24].upper()
    return h

def generate_project():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "DovvoPlay"))
    proj_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "DovvoPlay.xcodeproj"))
    os.makedirs(proj_dir, exist_ok=True)
    shared_schemes_dir = os.path.join(proj_dir, "xcshareddata", "xcschemes")
    os.makedirs(shared_schemes_dir, exist_ok=True)

    # Collect all swift files
    swift_files = []
    for root, dirs, files in os.walk(base_dir):
        for f in files:
            if f.endswith(".swift"):
                rel_path = os.path.relpath(os.path.join(root, f), os.path.dirname(base_dir))
                rel_path = rel_path.replace("\\", "/")
                swift_files.append(rel_path)

    swift_files.sort()
    print(f"Found {len(swift_files)} Swift files.")

    # Assets & plist
    assets_path = "DovvoPlay/Resources/Assets.xcassets"
    info_plist_path = "DovvoPlay/Resources/Info.plist"

    # UUIDs
    proj_uuid = make_uuid("DovvoPlay_PBXProject")
    target_uuid = make_uuid("DovvoPlay_PBXNativeTarget")
    main_group_uuid = make_uuid("DovvoPlay_MainGroup")
    products_group_uuid = make_uuid("DovvoPlay_ProductsGroup")
    app_product_uuid = make_uuid("DovvoPlay_ProductRef")

    sources_build_phase_uuid = make_uuid("DovvoPlay_SourcesBuildPhase")
    resources_build_phase_uuid = make_uuid("DovvoPlay_ResourcesBuildPhase")
    frameworks_build_phase_uuid = make_uuid("DovvoPlay_FrameworksBuildPhase")

    proj_config_list_uuid = make_uuid("DovvoPlay_ProjConfigList")
    proj_debug_config_uuid = make_uuid("DovvoPlay_ProjDebugConfig")
    proj_release_config_uuid = make_uuid("DovvoPlay_ProjReleaseConfig")

    target_config_list_uuid = make_uuid("DovvoPlay_TargetConfigList")
    target_debug_config_uuid = make_uuid("DovvoPlay_TargetDebugConfig")
    target_release_config_uuid = make_uuid("DovvoPlay_TargetReleaseConfig")

    assets_fileref_uuid = make_uuid(assets_path + "_fileref")
    assets_buildfile_uuid = make_uuid(assets_path + "_buildfile")
    plist_fileref_uuid = make_uuid(info_plist_path + "_fileref")

    # File references and build files for Swift
    swift_file_refs = {}
    swift_build_files = {}
    for sf in swift_files:
        fref = make_uuid(sf + "_fileref")
        bfile = make_uuid(sf + "_buildfile")
        swift_file_refs[sf] = fref
        swift_build_files[sf] = bfile

    # Build group hierarchy
    # Groups:
    # DovvoPlay (folder)
    #   App
    #   Models
    #   Services
    #   UI
    #     Components
    #     Screens
    #     Theme
    #   Resources
    group_uuids = {
        "DovvoPlay": make_uuid("grp_DovvoPlay"),
        "DovvoPlay/App": make_uuid("grp_DovvoPlay/App"),
        "DovvoPlay/Models": make_uuid("grp_DovvoPlay/Models"),
        "DovvoPlay/Services": make_uuid("grp_DovvoPlay/Services"),
        "DovvoPlay/UI": make_uuid("grp_DovvoPlay/UI"),
        "DovvoPlay/UI/Components": make_uuid("grp_DovvoPlay/UI/Components"),
        "DovvoPlay/UI/Screens": make_uuid("grp_DovvoPlay/UI/Screens"),
        "DovvoPlay/UI/Theme": make_uuid("grp_DovvoPlay/UI/Theme"),
        "DovvoPlay/Resources": make_uuid("grp_DovvoPlay/Resources"),
    }

    # Group children
    group_children = {k: [] for k in group_uuids}
    group_children["DovvoPlay"].extend([
        (group_uuids["DovvoPlay/App"], "App"),
        (group_uuids["DovvoPlay/Models"], "Models"),
        (group_uuids["DovvoPlay/Services"], "Services"),
        (group_uuids["DovvoPlay/UI"], "UI"),
        (group_uuids["DovvoPlay/Resources"], "Resources"),
    ])
    group_children["DovvoPlay/UI"].extend([
        (group_uuids["DovvoPlay/UI/Components"], "Components"),
        (group_uuids["DovvoPlay/UI/Screens"], "Screens"),
        (group_uuids["DovvoPlay/UI/Theme"], "Theme"),
    ])
    group_children["DovvoPlay/Resources"].extend([
        (assets_fileref_uuid, "Assets.xcassets"),
        (plist_fileref_uuid, "Info.plist"),
    ])

    for sf in swift_files:
        parts = sf.split("/")
        filename = parts[-1]
        folder = "/".join(parts[:-1])
        if folder in group_children:
            group_children[folder].append((swift_file_refs[sf], filename))

    lines = []
    lines.append("// !$*UTF8*$!")
    lines.append("{")
    lines.append("\tarchiveVersion = 1;")
    lines.append("\tclasses = {")
    lines.append("\t};")
    lines.append("\tobjectVersion = 54;")
    lines.append("\tobjects = {")
    lines.append("")

    # PBXBuildFile
    lines.append("/* Begin PBXBuildFile section */")
    lines.append(f"\t\t{assets_buildfile_uuid} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_fileref_uuid} /* Assets.xcassets */; }};")
    for sf in swift_files:
        bf = swift_build_files[sf]
        fr = swift_file_refs[sf]
        fn = os.path.basename(sf)
        lines.append(f"\t\t{bf} /* {fn} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {fn} */; }};")
    lines.append("/* End PBXBuildFile section */")
    lines.append("")

    # PBXFileReference
    lines.append("/* Begin PBXFileReference section */")
    lines.append(f"\t\t{app_product_uuid} /* DovvoPlay.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DovvoPlay.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    lines.append(f"\t\t{assets_fileref_uuid} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
    lines.append(f"\t\t{plist_fileref_uuid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
    for sf in swift_files:
        fr = swift_file_refs[sf]
        fn = os.path.basename(sf)
        lines.append(f"\t\t{fr} /* {fn} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{fn}\"; sourceTree = \"<group>\"; }};")
    lines.append("/* End PBXFileReference section */")
    lines.append("")

    # PBXFrameworksBuildPhase
    lines.append("/* Begin PBXFrameworksBuildPhase section */")
    lines.append(f"\t\t{frameworks_build_phase_uuid} /* Frameworks */ = {{")
    lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXFrameworksBuildPhase section */")
    lines.append("")

    # PBXGroup
    lines.append("/* Begin PBXGroup section */")
    # Main group
    lines.append(f"\t\t{main_group_uuid} = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{group_uuids['DovvoPlay']} /* DovvoPlay */,")
    lines.append(f"\t\t\t\t{products_group_uuid} /* Products */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    # Products group
    lines.append(f"\t\t{products_group_uuid} /* Products */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{app_product_uuid} /* DovvoPlay.app */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Products;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    # Inner groups
    for gpath, guuid in group_uuids.items():
        name = gpath.split("/")[-1]
        lines.append(f"\t\t{guuid} /* {name} */ = {{")
        lines.append("\t\t\tisa = PBXGroup;")
        lines.append("\t\t\tchildren = (")
        for child_uuid, child_name in group_children[gpath]:
            lines.append(f"\t\t\t\t{child_uuid} /* {child_name} */,")
        lines.append("\t\t\t);")
        lines.append(f"\t\t\tpath = \"{name}\";")
        lines.append("\t\t\tsourceTree = \"<group>\";")
        lines.append("\t\t};")
    lines.append("/* End PBXGroup section */")
    lines.append("")

    # PBXNativeTarget
    lines.append("/* Begin PBXNativeTarget section */")
    lines.append(f"\t\t{target_uuid} /* DovvoPlay */ = {{")
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {target_config_list_uuid} /* Build configuration list for PBXNativeTarget \"DovvoPlay\" */;")
    lines.append("\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{sources_build_phase_uuid} /* Sources */,")
    lines.append(f"\t\t\t\t{frameworks_build_phase_uuid} /* Frameworks */,")
    lines.append(f"\t\t\t\t{resources_build_phase_uuid} /* Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdependencies = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = DovvoPlay;")
    lines.append("\t\t\tproductName = DovvoPlay;")
    lines.append(f"\t\t\tproductReference = {app_product_uuid} /* DovvoPlay.app */;")
    lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append("\t\t};")
    lines.append("/* End PBXNativeTarget section */")
    lines.append("")

    # PBXProject
    lines.append("/* Begin PBXProject section */")
    lines.append(f"\t\t{proj_uuid} /* Project object */ = {{")
    lines.append("\t\t\tisa = PBXProject;")
    lines.append("\t\t\tattributes = {")
    lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    lines.append("\t\t\t\tLastUpgradeCheck = 1520;")
    lines.append("\t\t\t\tTargetAttributes = {")
    lines.append(f"\t\t\t\t\t{target_uuid} = {{")
    lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    lines.append("\t\t\t\t\t};")
    lines.append("\t\t\t\t};")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tbuildConfigurationList = {proj_config_list_uuid} /* Build configuration list for PBXProject \"DovvoPlay\" */;")
    lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    lines.append("\t\t\tdevelopmentRegion = en;")
    lines.append("\t\t\thasScannedForEncodings = 0;")
    lines.append("\t\t\tknownRegions = (")
    lines.append("\t\t\t\ten,")
    lines.append("\t\t\t\tBase,")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\tmainGroup = {main_group_uuid};")
    lines.append(f"\t\t\tproductRefGroup = {products_group_uuid} /* Products */;")
    lines.append("\t\t\tprojectDirPath = \"\";")
    lines.append("\t\t\tprojectRoot = \"\";")
    lines.append("\t\t\ttargets = (")
    lines.append(f"\t\t\t\t{target_uuid} /* DovvoPlay */,")
    lines.append("\t\t\t);")
    lines.append("\t\t};")
    lines.append("/* End PBXProject section */")
    lines.append("")

    # PBXResourcesBuildPhase
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    lines.append(f"\t\t{resources_build_phase_uuid} /* Resources */ = {{")
    lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append(f"\t\t\t\t{assets_buildfile_uuid} /* Assets.xcassets in Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXResourcesBuildPhase section */")
    lines.append("")

    # PBXSourcesBuildPhase
    lines.append("/* Begin PBXSourcesBuildPhase section */")
    lines.append(f"\t\t{sources_build_phase_uuid} /* Sources */ = {{")
    lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for sf in swift_files:
        bf = swift_build_files[sf]
        fn = os.path.basename(sf)
        lines.append(f"\t\t\t\t{bf} /* {fn} in Sources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXSourcesBuildPhase section */")
    lines.append("")

    # XCBuildConfiguration
    lines.append("/* Begin XCBuildConfiguration section */")
    # Project Debug
    lines.append(f"\t\t{proj_debug_config_uuid} /* Debug */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    lines.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    lines.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    lines.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    lines.append("\t\t\t\tENABLE_TESTABILITY = YES;")
    lines.append("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
    lines.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
    lines.append("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
    lines.append("\t\t\t\t\t\"DEBUG=1\",")
    lines.append("\t\t\t\t\t\"$(inherited)\",")
    lines.append("\t\t\t\t);")
    lines.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;")
    lines.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
    lines.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
    lines.append("\t\t\t\tSDKROOT = iphoneos;")
    lines.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
    lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
    lines.append("\t\t\t};")
    lines.append("\t\t\tname = Debug;")
    lines.append("\t\t};")

    # Project Release
    lines.append(f"\t\t{proj_release_config_uuid} /* Release */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    lines.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    lines.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    lines.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    lines.append("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
    lines.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;")
    lines.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
    lines.append("\t\t\t\tSDKROOT = iphoneos;")
    lines.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
    lines.append("\t\t\t\tVALIDATE_PRODUCT = YES;")
    lines.append("\t\t\t};")
    lines.append("\t\t\tname = Release;")
    lines.append("\t\t};")

    # Target Debug
    lines.append(f"\t\t{target_debug_config_uuid} /* Debug */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    lines.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
    lines.append("\t\t\t\tCODE_SIGNING_ALLOWED = NO;")
    lines.append("\t\t\t\tCODE_SIGNING_REQUIRED = NO;")
    lines.append("\t\t\t\tCODE_SIGN_IDENTITY = \"\";")
    lines.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    lines.append("\t\t\t\tENABLE_BITCODE = NO;")
    lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    lines.append("\t\t\t\tINFOPLIST_FILE = DovvoPlay/Resources/Info.plist;")
    lines.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;")
    lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    lines.append("\t\t\t\t\t\"$(inherited)\",")
    lines.append("\t\t\t\t\t\"@executable_path/Frameworks\",")
    lines.append("\t\t\t\t);")
    lines.append("\t\t\t\tMARKETING_VERSION = 2.0.0;")
    lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.dchietti.dovvoplay;")
    lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    lines.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    lines.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
    lines.append("\t\t\t};")
    lines.append("\t\t\tname = Debug;")
    lines.append("\t\t};")

    # Target Release
    lines.append(f"\t\t{target_release_config_uuid} /* Release */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    lines.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
    lines.append("\t\t\t\tCODE_SIGNING_ALLOWED = NO;")
    lines.append("\t\t\t\tCODE_SIGNING_REQUIRED = NO;")
    lines.append("\t\t\t\tCODE_SIGN_IDENTITY = \"\";")
    lines.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    lines.append("\t\t\t\tENABLE_BITCODE = NO;")
    lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    lines.append("\t\t\t\tINFOPLIST_FILE = DovvoPlay/Resources/Info.plist;")
    lines.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;")
    lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    lines.append("\t\t\t\t\t\"$(inherited)\",")
    lines.append("\t\t\t\t\t\"@executable_path/Frameworks\",")
    lines.append("\t\t\t\t);")
    lines.append("\t\t\t\tMARKETING_VERSION = 2.0.0;")
    lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.dchietti.dovvoplay;")
    lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    lines.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    lines.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
    lines.append("\t\t\t};")
    lines.append("\t\t\tname = Release;")
    lines.append("\t\t};")
    lines.append("/* End XCBuildConfiguration section */")
    lines.append("")

    # XCConfigurationList
    lines.append("/* Begin XCConfigurationList section */")
    lines.append(f"\t\t{proj_config_list_uuid} /* Build configuration list for PBXProject \"DovvoPlay\" */ = {{")
    lines.append("\t\t\tisa = XCConfigurationList;")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{proj_debug_config_uuid} /* Debug */,")
    lines.append(f"\t\t\t\t{proj_release_config_uuid} /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")

    lines.append(f"\t\t{target_config_list_uuid} /* Build configuration list for PBXNativeTarget \"DovvoPlay\" */ = {{")
    lines.append("\t\t\tisa = XCConfigurationList;")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{target_debug_config_uuid} /* Debug */,")
    lines.append(f"\t\t\t\t{target_release_config_uuid} /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")
    lines.append("/* End XCConfigurationList section */")
    lines.append("")

    lines.append("\t};")
    lines.append(f"\trootObject = {proj_uuid} /* Project object */;")
    lines.append("}")
    lines.append("")

    project_pbxproj_path = os.path.join(proj_dir, "project.pbxproj")
    with open(project_pbxproj_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Generated {project_pbxproj_path}")

    # Generate Shared Scheme
    scheme_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1520"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_uuid}"
               BuildableName = "DovvoPlay.app"
               BlueprintName = "DovvoPlay"
               ReferencedContainer = "container:DovvoPlay.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_uuid}"
            BuildableName = "DovvoPlay.app"
            BlueprintName = "DovvoPlay"
            ReferencedContainer = "container:DovvoPlay.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_uuid}"
            BuildableName = "DovvoPlay.app"
            BlueprintName = "DovvoPlay"
            ReferencedContainer = "container:DovvoPlay.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    scheme_path = os.path.join(shared_schemes_dir, "DovvoPlay.xcscheme")
    with open(scheme_path, "w", encoding="utf-8") as f:
        f.write(scheme_content)
    print(f"Generated {scheme_path}")

if __name__ == "__main__":
    generate_project()
