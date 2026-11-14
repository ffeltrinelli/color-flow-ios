#!/usr/bin/env python3
"""Reproduce the dependency-free Xcode project after changing target membership."""
from pathlib import Path
import hashlib

objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name, value):
    key = uid(name)
    objects[key] = value
    return key
def array(values): return '(' + ', '.join(values) + ')'
def ref(path, kind):
    return add(path, f'{{isa = PBXFileReference; lastKnownFileType = {kind}; path = "{path}"; sourceTree = SOURCE_ROOT;}}')
def build(name, refid): return add(name, f'{{isa = PBXBuildFile; fileRef = {refid};}}')

project = uid('project')
package = add('package', '{isa = XCLocalSwiftPackageReference; relativePath = .;}')
config = ref('Config/Signing.xcconfig','text.xcconfig')
appfiles = sorted(Path('App').glob('*.swift'))
testfiles = sorted(Path('Tests/ColorFlowCoreTests').glob('*.swift'))
uifiles = sorted(Path('UITests').glob('*.swift'))
fileids = []
targets = []
products = []
for name, files, producttype, extension in [
    ('ColorFlow',appfiles,'application','app'),
    ('ColorFlowTests',testfiles,'bundle.unit-test','xctest'),
    ('ColorFlowUITests',uifiles,'bundle.ui-testing','xctest')]:
    sourcebuilds=[]
    for file in files:
        fileid=ref(str(file),'sourcecode.swift'); fileids.append(fileid)
        sourcebuilds.append(build(name+str(file),fileid))
    sources=add(name+'sources', '{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = '+array(sourcebuilds)+'; runOnlyForDeploymentPostprocessing = 0;}')
    resourcebuilds=[]
    if name=='ColorFlow':
        assets=ref('App/Assets.xcassets','folder.assetcatalog'); fileids.append(assets)
        resourcebuilds.append(build(name+'assets',assets))
    resources=add(name+'resources', '{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = '+array(resourcebuilds)+'; runOnlyForDeploymentPostprocessing = 0;}')
    product=add(name+'product',f'{{isa = PBXFileReference; explicitFileType = {"wrapper.application" if extension=="app" else "wrapper.cfbundle"}; path = {name}.{extension}; sourceTree = BUILT_PRODUCTS_DIR;}}')
    products.append(product)
    linked=[]; deps=[]
    productdep=add(name+'core','{isa = XCSwiftPackageProductDependency; package = '+package+'; productName = ColorFlowCore;}')
    deps.append(productdep)
    linked.append(add(name+'corebuild','{isa = PBXBuildFile; productRef = '+productdep+';}'))
    frameworks=add(name+'frameworks','{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = '+array(linked)+'; runOnlyForDeploymentPostprocessing = 0;}')
    targetdeps=[]
    if name!='ColorFlow':
        proxy=add(name+'proxy',f'{{isa = PBXContainerItemProxy; containerPortal = {project}; proxyType = 1; remoteGlobalIDString = {uid("ColorFlowtarget")}; remoteInfo = ColorFlow;}}')
        targetdeps.append(add(name+'dependency',f'{{isa = PBXTargetDependency; target = {uid("ColorFlowtarget")}; targetProxy = {proxy};}}'))
    configs=[]
    for mode in ['Debug','Release']:
        settings={
          'PRODUCT_NAME':'"$(TARGET_NAME)"','PRODUCT_BUNDLE_IDENTIFIER':'"$(BUNDLE_IDENTIFIER_PREFIX).$(TARGET_NAME)"',
          'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','TARGETED_DEVICE_FAMILY':'1',
          'SWIFT_VERSION':'6.0','GENERATE_INFOPLIST_FILE':'YES','CODE_SIGN_STYLE':'Automatic',
          'SUPPORTED_PLATFORMS':'"iphoneos iphonesimulator"','SUPPORTS_MACCATALYST':'NO',
          'SWIFT_OPTIMIZATION_LEVEL':'"-Onone"' if mode=='Debug' else '"-O"',
          'ONLY_ACTIVE_ARCH':'YES' if mode=='Debug' else 'NO',
          'LD_RUNPATH_SEARCH_PATHS':'"$(inherited) @executable_path/Frameworks @loader_path/Frameworks"',
        }
        if name=='ColorFlow':
            settings.update({'INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait',
              'INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UILaunchScreen_Generation':'YES',
              'INFOPLIST_KEY_CFBundleDisplayName':'"Color Flow"','ENABLE_TESTABILITY':'YES',
              'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon'})
        elif name=='ColorFlowUITests': settings['TEST_TARGET_NAME']='ColorFlow'
        settings_text=' '.join(f'{k} = {v};' for k,v in settings.items())
        configs.append(add(name+mode,f'{{isa = XCBuildConfiguration; baseConfigurationReference = {config}; buildSettings = {{{settings_text}}}; name = {mode};}}'))
    configlist=add(name+'configs','{isa = XCConfigurationList; buildConfigurations = '+array(configs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
    targets.append(add(name+'target',f'{{isa = PBXNativeTarget; buildConfigurationList = {configlist}; buildPhases = {array([sources,frameworks,resources])}; buildRules = (); dependencies = {array(targetdeps)}; name = {name}; packageProductDependencies = {array(deps)}; productName = {name}; productReference = {product}; productType = "com.apple.product-type.{producttype}";}}'))
productgroup=add('products','{isa = PBXGroup; children = '+array(products)+'; name = Products; sourceTree = "<group>";}')
group=add('main','{isa = PBXGroup; children = '+array(fileids+[config,productgroup])+'; sourceTree = "<group>";}')
configs=[]
for mode in ['Debug','Release']:
    configs.append(add('project'+mode,f'{{isa = XCBuildConfiguration; buildSettings = {{CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 6.0; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; DEBUG_INFORMATION_FORMAT = dwarf;}}; name = {mode};}}'))
configlist=add('projectconfigs','{isa = XCConfigurationList; buildConfigurations = '+array(configs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
add('project',f'{{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700;}}; buildConfigurationList = {configlist}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = {group}; productRefGroup = {productgroup}; projectDirPath = ""; projectRoot = ""; packageReferences = ({package}); targets = {array(targets)};}}')
Path('ColorFlow.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(f'{key} = {value};' for key,value in objects.items())+f'\n}}; rootObject = {project};\n}}\n')

def buildable(name):
    ext='app' if name=='ColorFlow' else 'xctest'
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(name+"target")}" BuildableName="{name}.{ext}" BlueprintName="{name}" ReferencedContainer="container:ColorFlow.xcodeproj"/>'
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable('ColorFlow')}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES" preferredScreenCaptureFormat="screenshots"><Testables>
<TestableReference skipped="NO">{buildable('ColorFlowTests')}</TestableReference>
<TestableReference skipped="NO">{buildable('ColorFlowUITests')}</TestableReference>
</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('ColorFlow')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('ColorFlow')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
Path('ColorFlow.xcodeproj/xcshareddata/xcschemes/ColorFlow.xcscheme').write_text(scheme+'\n')
