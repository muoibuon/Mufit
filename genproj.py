import os, pathlib, hashlib

# Bật bằng MUFIT_SIDELOAD=1: dựng bản cho AltStore — bỏ widget và bỏ mọi entitlement,
# vì Apple ID miễn phí không được cấp App Groups lẫn Sign in with Apple.
SIDELOAD = os.environ.get("MUFIT_SIDELOAD") == "1"

ROOT = pathlib.Path.home() / "Developer/Mufit"
os.chdir(ROOT)

def oid(key):
    return hashlib.sha1(key.encode()).hexdigest()[:24].upper()

def collect(folder, ext=".swift"):
    return sorted(str(p) for p in pathlib.Path(folder).rglob("*" + ext))

shared_swift = collect("Shared")
app_swift    = collect("App")
widget_swift = collect("Widgets")
test_swift   = collect("MufitUITests")
resources    = sorted(str(p) for p in pathlib.Path("Shared/Resources").rglob("*.json"))
# Asset catalog được Xcode coi là một thư mục duy nhất, không phải từng file lẻ.
asset_catalogs = sorted(str(p) for p in pathlib.Path(".").glob("*/*.xcassets"))
resources += asset_catalogs

all_files = shared_swift + app_swift + widget_swift + test_swift + resources + [
    "App/Info.plist", "Widgets/Info.plist",
    "App/Mufit.entitlements", "Widgets/MufitWidgets.entitlements",
]

# ---------- PBXFileReference ----------
def filetype(path):
    if path.endswith(".swift"): return "sourcecode.swift"
    if path.endswith(".json"):  return "text.json"
    if path.endswith(".plist"): return "text.plist.xml"
    if path.endswith(".entitlements"): return "text.plist.entitlements"
    if path.endswith(".xcassets"): return "folder.assetcatalog"
    return "text"

frefs = []
for f in all_files:
    frefs.append(f'\t\t{oid("fref:"+f)} /* {pathlib.Path(f).name} */ = {{isa = PBXFileReference; '
                 f'lastKnownFileType = {filetype(f)}; path = "{pathlib.Path(f).name}"; sourceTree = "<group>"; }};')

APP_PROD = oid("prod:app")
WID_PROD = oid("prod:widget")
TEST_PROD = oid("prod:uitests")
frefs.append(f'\t\t{APP_PROD} /* Mufit.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Mufit.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
frefs.append(f'\t\t{WID_PROD} /* MufitWidgets.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = MufitWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR; }};')
frefs.append(f'\t\t{TEST_PROD} /* MufitUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = MufitUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')

# ---------- PBXBuildFile ----------
bfiles = []
def build_file(path, target):
    i = oid(f"bf:{target}:{path}")
    bfiles.append(f'\t\t{i} /* {pathlib.Path(path).name} in {target} */ = {{isa = PBXBuildFile; fileRef = {oid("fref:"+path)}; }};')
    return i

app_src   = [build_file(f, "Sources-app")    for f in shared_swift + app_swift]
# AuthService dùng UIApplication.shared — API này bị cấm trong app extension,
# nên widget không biên dịch file đó (widget cũng không cần đăng nhập).
WIDGET_EXCLUDE = {"Shared/Services/AuthService.swift"}
wid_src   = [build_file(f, "Sources-widget")
             for f in shared_swift + widget_swift if f not in WIDGET_EXCLUDE]
app_res   = [build_file(f, "Resources-app")  for f in resources]
test_src  = [build_file(f, "Sources-tests") for f in test_swift]

EMBED_BF = oid("bf:embed:widget")
bfiles.append(f'\t\t{EMBED_BF} /* FitCoreWidgets.appex in Embed */ = {{isa = PBXBuildFile; fileRef = {WID_PROD}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};')

# ---------- Groups: dựng cây thư mục thật ----------
groups = []
def make_group(dirpath, children_files):
    """Tạo group cho một thư mục, đệ quy xuống thư mục con."""
    p = pathlib.Path(dirpath)
    subdirs = sorted({str(pathlib.Path(f).parent) for f in children_files
                      if str(pathlib.Path(f).parent) != dirpath
                      and str(pathlib.Path(f).parent).startswith(dirpath + "/")})
    direct_subdirs = sorted({d for d in subdirs if pathlib.Path(d).parent == p})
    own = [f for f in children_files if str(pathlib.Path(f).parent) == dirpath]

    child_ids = [f'{make_group(d, children_files)} /* {pathlib.Path(d).name} */' for d in direct_subdirs]
    child_ids += [f'{oid("fref:"+f)} /* {pathlib.Path(f).name} */' for f in sorted(own)]

    gid = oid("grp:" + dirpath)
    kids = "\n".join(f"\t\t\t\t{c}," for c in child_ids)
    groups.append(f'''\t\t{gid} /* {p.name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{kids}
\t\t\t);
\t\t\tpath = "{p.name}";
\t\t\tsourceTree = "<group>";
\t\t}};''')
    return gid

g_shared  = make_group("Shared",  shared_swift + resources)
g_app     = make_group("App",     app_swift + ["App/Info.plist", "App/Mufit.entitlements"] + asset_catalogs)
g_widgets = make_group("Widgets", widget_swift + ["Widgets/Info.plist", "Widgets/MufitWidgets.entitlements"])
g_tests   = make_group("MufitUITests", test_swift)

PROD_GRP = oid("grp:products")
groups.append(f'''\t\t{PROD_GRP} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{APP_PROD} /* Mufit.app */,
\t\t\t\t{WID_PROD} /* MufitWidgets.appex */,
\t\t\t\t{TEST_PROD} /* MufitUITests.xctest */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};''')

ROOT_GRP = oid("grp:root")
groups.append(f'''\t\t{ROOT_GRP} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{g_shared} /* Shared */,
\t\t\t\t{g_app} /* App */,
\t\t\t\t{g_widgets} /* Widgets */,
\t\t\t\t{g_tests} /* MufitUITests */,
\t\t\t\t{PROD_GRP} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};''')

def phase(pid, isa, files, extra=""):
    lst = "\n".join(f"\t\t\t\t{f}," for f in files)
    return f'''\t\t{pid} = {{
\t\t\tisa = {isa};
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{lst}
\t\t\t);
{extra}\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};'''

APP_SRC_PH = oid("ph:appsrc");  WID_SRC_PH = oid("ph:widsrc")
APP_RES_PH = oid("ph:appres");  WID_RES_PH = oid("ph:widres")
APP_FRM_PH = oid("ph:appfrm");  WID_FRM_PH = oid("ph:widfrm")
TEST_SRC_PH = oid("ph:testsrc"); TEST_FRM_PH = oid("ph:testfrm"); TEST_RES_PH = oid("ph:testres")
EMBED_PH   = oid("ph:embed")

phases = [
    phase(APP_SRC_PH, "PBXSourcesBuildPhase", app_src),
    phase(WID_SRC_PH, "PBXSourcesBuildPhase", wid_src),
    phase(APP_RES_PH, "PBXResourcesBuildPhase", app_res),
    phase(WID_RES_PH, "PBXResourcesBuildPhase", []),
    phase(APP_FRM_PH, "PBXFrameworksBuildPhase", []),
    phase(WID_FRM_PH, "PBXFrameworksBuildPhase", []),
    phase(EMBED_PH, "PBXCopyFilesBuildPhase", [f'{EMBED_BF} /* MufitWidgets.appex */'],
          extra='\t\t\tdstPath = "";\n\t\t\tdstSubfolderSpec = 13;\n\t\t\tname = "Embed Foundation Extensions";\n'),
    phase(TEST_SRC_PH, "PBXSourcesBuildPhase", test_src),
    phase(TEST_FRM_PH, "PBXFrameworksBuildPhase", []),
    phase(TEST_RES_PH, "PBXResourcesBuildPhase", []),
]

# ---------- Cấu hình build ----------
BASE = '''\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";'''

def target_settings(name, bundle_id, infoplist, entitlements, is_ext):
    s = f'''\t\t\t\tCODE_SIGN_ENTITLEMENTS = "{entitlements}";
\t\t\t\tCODE_SIGN_IDENTITY = "{"Apple Development" if SIDELOAD else "-"}";
\t\t\t\tCODE_SIGN_STYLE = {"Automatic" if SIDELOAD else "Manual"};
\t\t\t\tCODE_SIGNING_ALLOWED = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = "{infoplist}";
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {bundle_id};
\t\t\t\tPRODUCT_NAME = "{name}";
\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "";
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;'''
    if SIDELOAD:
        s += '\n\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "SIDELOAD $(inherited)";'
    if is_ext:
        s += '''
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tSKIP_INSTALL = YES;'''
    else:
        s += '''
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);'''
    return s

configs = []
def add_config(cid, name, body):
    configs.append(f'''\t\t{cid} /* {name} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{body}
\t\t\t}};
\t\t\tname = {name};
\t\t}};''')

PROJ_DEBUG, PROJ_REL = oid("cfg:proj:debug"), oid("cfg:proj:release")
add_config(PROJ_DEBUG, "Debug", BASE + '''
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)");
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";''')
add_config(PROJ_REL, "Release", BASE + '''
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tVALIDATE_PRODUCT = YES;''')

APP_DEBUG, APP_REL = oid("cfg:app:debug"), oid("cfg:app:release")
app_body = target_settings("Mufit", "com.muoi.fitcore",
                           "App/Info.plist",
                           "App/Mufit-Sideload.entitlements" if SIDELOAD else "App/Mufit.entitlements",
                           False)
add_config(APP_DEBUG, "Debug", app_body)
add_config(APP_REL, "Release", app_body)

WID_DEBUG, WID_REL = oid("cfg:wid:debug"), oid("cfg:wid:release")
wid_body = target_settings("MufitWidgets", "com.muoi.fitcore.widgets", "Widgets/Info.plist", "Widgets/MufitWidgets.entitlements", True)
add_config(WID_DEBUG, "Debug", wid_body)
add_config(WID_REL, "Release", wid_body)

TEST_DEBUG, TEST_REL = oid("cfg:test:debug"), oid("cfg:test:release")
test_body = '''\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.muoi.MufitUITests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tTEST_TARGET_NAME = Mufit;'''
add_config(TEST_DEBUG, "Debug", test_body)
add_config(TEST_REL, "Release", test_body)

def conflist(cid, label, debug, rel):
    return f'''\t\t{cid} /* {label} */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug} /* Debug */,
\t\t\t\t{rel} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};'''

PROJ_CL, APP_CL, WID_CL, TEST_CL = oid("cl:proj"), oid("cl:app"), oid("cl:wid"), oid("cl:test")
conflists = [
    conflist(PROJ_CL, 'Build configuration list for PBXProject "Mufit"', PROJ_DEBUG, PROJ_REL),
    conflist(APP_CL, 'Build configuration list for PBXNativeTarget "Mufit"', APP_DEBUG, APP_REL),
    conflist(WID_CL, 'Build configuration list for PBXNativeTarget "MufitWidgets"', WID_DEBUG, WID_REL),
    conflist(TEST_CL, 'Build configuration list for PBXNativeTarget "MufitUITests"', TEST_DEBUG, TEST_REL),
]

APP_TGT, WID_TGT = oid("tgt:app"), oid("tgt:wid")
PROXY, DEP = oid("proxy:wid"), oid("dep:wid")
TEST_TGT, TEST_PROXY, TEST_DEP = oid("tgt:uitests"), oid("proxy:uitests"), oid("dep:uitests")
PROJ = oid("project")

out = f'''// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(bfiles)}
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		{PROXY} = {{
			isa = PBXContainerItemProxy;
			containerPortal = {PROJ};
			proxyType = 1;
			remoteGlobalIDString = {WID_TGT};
			remoteInfo = MufitWidgets;
		}};
		{TEST_PROXY} = {{
			isa = PBXContainerItemProxy;
			containerPortal = {PROJ};
			proxyType = 1;
			remoteGlobalIDString = {APP_TGT};
			remoteInfo = Mufit;
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
{phases[6]}
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
{chr(10).join(frefs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
{phases[4]}
{phases[5]}
{phases[8]}
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{chr(10).join(groups)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{APP_TGT} /* FitCore */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {APP_CL};
			buildPhases = (
				{APP_SRC_PH} /* Sources */,
				{APP_FRM_PH} /* Frameworks */,
				{APP_RES_PH} /* Resources */,
{"" if SIDELOAD else "\t\t\t\t" + EMBED_PH + " /* Embed Foundation Extensions */,"}
			);
			buildRules = ();
			dependencies = (
{"" if SIDELOAD else "\t\t\t\t" + DEP + " /* PBXTargetDependency */,"}
			);
			name = Mufit;
			productName = Mufit;
			productReference = {APP_PROD};
			productType = "com.apple.product-type.application";
		}};
		{WID_TGT} /* FitCoreWidgets */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {WID_CL};
			buildPhases = (
				{WID_SRC_PH} /* Sources */,
				{WID_FRM_PH} /* Frameworks */,
				{WID_RES_PH} /* Resources */,
			);
			buildRules = ();
			dependencies = ();
			name = MufitWidgets;
			productName = MufitWidgets;
			productReference = {WID_PROD};
			productType = "com.apple.product-type.app-extension";
		}};
		{TEST_TGT} /* MufitUITests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {TEST_CL};
			buildPhases = (
				{TEST_SRC_PH} /* Sources */,
				{TEST_FRM_PH} /* Frameworks */,
				{TEST_RES_PH} /* Resources */,
			);
			buildRules = ();
			dependencies = (
				{TEST_DEP} /* PBXTargetDependency */,
			);
			name = MufitUITests;
			productName = MufitUITests;
			productReference = {TEST_PROD};
			productType = "com.apple.product-type.bundle.ui-testing";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{PROJ} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2660;
				LastUpgradeCheck = 2660;
				TargetAttributes = {{
					{APP_TGT} = {{ CreatedOnToolsVersion = 26.6; }};
					{WID_TGT} = {{ CreatedOnToolsVersion = 26.6; }};
					{TEST_TGT} = {{ CreatedOnToolsVersion = 27.0; TestTargetID = {APP_TGT}; }};
				}};
			}};
			buildConfigurationList = {PROJ_CL};
			developmentRegion = vi;
			hasScannedForEncodings = 0;
			knownRegions = ( vi, Base, );
			mainGroup = {ROOT_GRP};
			productRefGroup = {PROD_GRP};
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{APP_TGT} /* Mufit */,
{"" if SIDELOAD else "\t\t\t\t" + WID_TGT + " /* MufitWidgets */,"}
				{TEST_TGT} /* MufitUITests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{phases[2]}
{phases[3]}
{phases[9]}
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{phases[0]}
{phases[1]}
{phases[7]}
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{DEP} = {{
			isa = PBXTargetDependency;
			target = {WID_TGT};
			targetProxy = {PROXY};
		}};
		{TEST_DEP} = {{
			isa = PBXTargetDependency;
			target = {APP_TGT};
			targetProxy = {TEST_PROXY};
		}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
{chr(10).join(configs)}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
{chr(10).join(conflists)}
/* End XCConfigurationList section */
	}};
	rootObject = {PROJ};
}}
'''

pathlib.Path("Mufit.xcodeproj/project.pbxproj").write_text(out, encoding="utf-8")
print(f"pbxproj: {len(shared_swift)} shared + {len(app_swift)} app + {len(widget_swift)} widget swift, {len(resources)} resource")
