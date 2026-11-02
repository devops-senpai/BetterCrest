#include "chrome/browser/ui/crest/crest_automation.h"

#include <CoreFoundation/CoreFoundation.h>

#include <cstdlib>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "base/apple/foundation_util.h"
#include "base/apple/scoped_cftyperef.h"
#include "base/command_line.h"
#include "base/logging.h"
#include "base/memory/weak_ptr.h"
#include "base/no_destructor.h"
#include "base/strings/string_number_conversions.h"
#include "base/strings/string_util.h"
#include "base/strings/sys_string_conversions.h"
#include "base/supports_user_data.h"
#include "chrome/browser/profiles/profile.h"
#include "chrome/browser/ui/crest/crest_chrome_hooks.h"
#include "chrome/browser/ui/crest/crest_engine_binding.h"
#include "chrome/browser/ui/crest/crest_engine_profiles.h"
#include "content/public/browser/devtools_agent_host.h"
#include "content/public/browser/navigation_controller.h"
#include "content/public/browser/render_frame_host.h"
#include "content/public/browser/web_contents.h"
#include "content/public/common/content_switches.h"

namespace crest::automation {

namespace {

constexpr char kProfileSwitch[] = "arma-automation-profile";
constexpr char kHostProfileSwitch[] = "arma-automation-host-profile";
constexpr char kTabsSwitch[] = "arma-automation-tabs";
constexpr char kEphemeralProfile[] = "ephemeral";
constexpr char kOpenedTabs[] = "opened";
constexpr char kAllTabs[] = "all";

// The app's settings, in its defaults domain.
constexpr char kEnabledKey[] = "arma.automation.enabled";
constexpr char kPortKey[] = "arma.automation.port";
constexpr char kProfileKey[] = "arma.automation.profile";
constexpr char kHostProfileKey[] = "arma.automation.hostProfile";
constexpr char kTabsKey[] = "arma.automation.tabs";
constexpr int kDefaultPort = 9222;
// The ports the app lets a person pick: unprivileged ones.
constexpr int kLowestPort = 1024;
constexpr int kHighestPort = 65535;

// The defaults domain the app names for this launch, which an isolated
// launch sets to the suite it keeps the settings in.
constexpr char kSettingsDomainVariable[] = "ARMA_AUTOMATION_DEFAULTS_SUITE";
// Otherwise, the domain an isolated launch with a persistence identity keeps
// its settings in, as the app's `BrowserLaunchEnvironment` names it.
constexpr char kIsolatedDomainPrefix[] = "com.senpaimedia.arma.isolated.";
constexpr char kIsolatedSessionVariable[] = "CREST_ISOLATED_SESSION";
constexpr char kIsolationIdVariable[] = "CREST_ISOLATED_PERSISTENCE_ID";
constexpr size_t kIsolationIdLength = 48;

// How deep a chain of pages opening pages is followed.
constexpr int kOpenerDepth = 16;

// The key of the mark a page automation opened carries.
const char kOpenedKey[] = "crest-automation-opened";

// What this launch's switches chose.
struct Choice {
  // Whether a profile was chosen at all; without one DevTools is Chromium's.
  bool requested = false;
  // Whether the choice is complete. An incomplete one exposes nothing.
  bool valid = false;
  bool ephemeral = false;
  // The chosen regular profile's id, empty for an ephemeral one.
  std::string profile;
  // The profile id whose Space shows pages of contexts DevTools browses in;
  // empty for an ephemeral choice that named none.
  std::string host;
  bool all_tabs = false;
};

// What automation keeps for the launch.
struct State {
  base::WeakPtr<Profile> ephemeral;
  // The browser contexts DevTools created, the ephemeral profile included.
  std::vector<base::WeakPtr<Profile>> contexts;
  int opening = 0;
};

// The canonical spelling of a profile id, or empty when `text` is none.
std::string ProfileId(const std::string& text) {
  const std::optional<engine::Guid> id = ParseGuid(text);
  return id ? GuidText(*id) : std::string();
}

bool IsTabChoice(const std::string& tabs) {
  return tabs == kOpenedTabs || tabs == kAllTabs;
}

Choice ReadChoice() {
  Choice choice;
  const base::CommandLine& command_line = *base::CommandLine::ForCurrentProcess();
  if (!IsEnabled() || !command_line.HasSwitch(kProfileSwitch)) {
    return choice;
  }
  choice.requested = true;
  const std::string profile = command_line.GetSwitchValueASCII(kProfileSwitch);
  choice.ephemeral = profile == kEphemeralProfile;
  choice.profile = choice.ephemeral ? std::string() : ProfileId(profile);
  choice.host = ProfileId(command_line.GetSwitchValueASCII(kHostProfileSwitch));
  if (choice.host.empty()) {
    choice.host = choice.profile;
  }
  const std::string tabs = command_line.HasSwitch(kTabsSwitch) ? command_line.GetSwitchValueASCII(kTabsSwitch)
                                                                : std::string(kOpenedTabs);
  choice.all_tabs = tabs == kAllTabs;
  choice.valid = (choice.ephemeral || !choice.profile.empty()) && IsTabChoice(tabs);
  if (!choice.valid) {
    LOG(ERROR) << "Arma automation: incomplete profile choice; remote debugging exposes no page.";
  }
  return choice;
}

const Choice& CurrentChoice() {
  static const base::NoDestructor<Choice> choice(ReadChoice());
  return *choice;
}

State& CurrentState() {
  static base::NoDestructor<State> state;
  return *state;
}

// The profile id whose Space shows the pages of contexts DevTools browses
// in: the one the choice names, or for an ephemeral choice that names none,
// the Space profile the engine loaded last, the Space the person is using.
std::string HostId() {
  const Choice& choice = CurrentChoice();
  return choice.host.empty() ? EngineBinding::Get().Profiles().last_regular() : choice.host;
}

bool IsContext(const content::BrowserContext* context) {
  for (const auto& created : CurrentState().contexts) {
    if (created && created.get() == context) {
      return true;
    }
  }
  return false;
}

void Mark(content::WebContents* contents) {
  contents->SetUserData(kOpenedKey, std::make_unique<base::SupportsUserData::Data>());
}

// Whether automation opened `contents`, or a page it opened did, with an
// opener. A page created while automation opens one, before its first
// navigation commits, is that page.
bool IsOpened(content::WebContents* contents, int depth) {
  contents = contents->GetOutermostWebContents();
  if (contents->GetUserData(kOpenedKey)) {
    return true;
  }
  if (CurrentState().opening > 0 && contents->GetController().IsInitialNavigation()) {
    Mark(contents);
    return true;
  }
  content::RenderFrameHost* opener = contents->GetOpener();
  content::WebContents* source = opener ? content::WebContents::FromRenderFrameHost(opener) : nullptr;
  if (!source || source == contents || depth >= kOpenerDepth || !IsOpened(source, depth + 1)) {
    return false;
  }
  Mark(contents);
  return true;
}

// The defaults domain the app keeps its settings in for this launch, or none
// for an isolated launch without a persistence identity, which keeps them
// nowhere the engine can read.
std::optional<std::string> SettingsDomain() {
  if (const char* named = std::getenv(kSettingsDomainVariable)) {
    return std::string(named);
  }
  if (const char* isolation = std::getenv(kIsolationIdVariable); isolation && *isolation) {
    std::string id;
    for (const char character : std::string_view(isolation)) {
      const char lower = base::ToLowerASCII(character);
      if (base::IsAsciiAlpha(lower) || base::IsAsciiDigit(lower) || lower == '-') {
        id.push_back(lower);
      }
    }
    if (!id.empty()) {
      return kIsolatedDomainPrefix + id.substr(0, kIsolationIdLength);
    }
  }
  if (const char* isolated = std::getenv(kIsolatedSessionVariable); isolated && std::string_view(isolated) == "1") {
    return std::nullopt;
  }
  return std::string();
}

// One setting from `domain`, or the app's standard domain when it is empty.
base::apple::ScopedCFTypeRef<CFPropertyListRef> ReadSetting(const std::string& domain, const char* key) {
  base::apple::ScopedCFTypeRef<CFStringRef> name = base::SysUTF8ToCFStringRef(key);
  base::apple::ScopedCFTypeRef<CFStringRef> application;
  if (!domain.empty()) {
    application = base::SysUTF8ToCFStringRef(domain);
  }
  return base::apple::ScopedCFTypeRef<CFPropertyListRef>(CFPreferencesCopyAppValue(
      name.get(), domain.empty() ? kCFPreferencesCurrentApplication : application.get()));
}

bool ReadBool(const std::string& domain, const char* key) {
  auto value = ReadSetting(domain, key);
  CFBooleanRef flag = base::apple::CFCast<CFBooleanRef>(value.get());
  if (flag) {
    return CFBooleanGetValue(flag);
  }
  CFNumberRef number = base::apple::CFCast<CFNumberRef>(value.get());
  int integer = 0;
  return number && CFNumberGetValue(number, kCFNumberIntType, &integer) && integer != 0;
}

std::optional<int> ReadInt(const std::string& domain, const char* key) {
  auto value = ReadSetting(domain, key);
  if (!value) {
    return std::nullopt;
  }
  int integer = 0;
  if (CFNumberRef number = base::apple::CFCast<CFNumberRef>(value.get())) {
    if (CFNumberGetValue(number, kCFNumberIntType, &integer)) {
      return integer;
    }
  } else if (CFStringRef text = base::apple::CFCast<CFStringRef>(value.get())) {
    if (base::StringToInt(base::SysCFStringRefToUTF8(text), &integer)) {
      return integer;
    }
  }
  return -1;
}

std::string ReadString(const std::string& domain, const char* key) {
  auto value = ReadSetting(domain, key);
  CFStringRef text = base::apple::CFCast<CFStringRef>(value.get());
  return text ? base::SysCFStringRefToUTF8(text) : std::string();
}

void AppendMissing(base::CommandLine& command_line, const char* name, const std::string& value) {
  if (!command_line.HasSwitch(name)) {
    command_line.AppendSwitchASCII(name, value);
  }
}

}  // namespace

// Reads the settings as the app's `BrowserAutomationPreferences` does: a port
// outside the unprivileged range is the default one, a profile that is
// neither a profile id nor `ephemeral` is ephemeral, and an unknown tab
// choice is `opened`.
void ApplySettings(base::CommandLine& command_line) {
  const std::optional<std::string> domain = SettingsDomain();
  if (!domain || !ReadBool(*domain, kEnabledKey)) {
    return;
  }
  int port = ReadInt(*domain, kPortKey).value_or(kDefaultPort);
  if (port < kLowestPort || port > kHighestPort) {
    port = kDefaultPort;
  }
  const std::string profile = ProfileId(ReadString(*domain, kProfileKey));
  const std::string host = ProfileId(ReadString(*domain, kHostProfileKey));
  std::string tabs = ReadString(*domain, kTabsKey);
  if (!IsTabChoice(tabs)) {
    tabs = kOpenedTabs;
  }
  if (!command_line.HasSwitch(switches::kRemoteDebuggingPort) &&
      !command_line.HasSwitch(switches::kRemoteDebuggingPipe)) {
    command_line.AppendSwitchASCII(switches::kRemoteDebuggingPort, base::NumberToString(port));
  }
  AppendMissing(command_line, kProfileSwitch, profile.empty() ? std::string(kEphemeralProfile) : profile);
  if (!host.empty()) {
    AppendMissing(command_line, kHostProfileSwitch, host);
  }
  AppendMissing(command_line, kTabsSwitch, tabs);
}

bool IsScoped() {
  return CurrentChoice().requested;
}

Profile* DefaultProfile() {
  const Choice& choice = CurrentChoice();
  if (!choice.valid) {
    return nullptr;
  }
  EngineBinding& binding = EngineBinding::Get();
  EngineProfiles& profiles = binding.Profiles();
  if (!choice.ephemeral) {
    return binding.disposing() ? profiles.Find(choice.profile) : profiles.LoadNow(choice.profile);
  }
  State& state = CurrentState();
  if (!state.ephemeral && !binding.disposing() && !HostId().empty()) {
    if (Profile* root = profiles.root()) {
      Profile* ephemeral =
          root->GetOffTheRecordProfile(Profile::OTRProfileID::CreateUniqueForDevTools(), /*create_if_needed=*/true);
      state.ephemeral = ephemeral->GetWeakPtr();
      AddContext(ephemeral);
    }
  }
  return state.ephemeral.get();
}

Profile* SourceProfile() {
  const Choice& choice = CurrentChoice();
  if (!choice.valid) {
    return nullptr;
  }
  if (!choice.ephemeral) {
    return DefaultProfile();
  }
  EngineBinding& binding = EngineBinding::Get();
  return binding.disposing() || HostId().empty() ? nullptr : binding.Profiles().root();
}

void AddContext(Profile* context) {
  if (!CurrentChoice().valid || !context) {
    return;
  }
  State& state = CurrentState();
  std::erase_if(state.contexts, [](const auto& created) { return !created; });
  state.contexts.push_back(context->GetWeakPtr());
  if (const std::string host = HostId(); !host.empty()) {
    EngineBinding::Get().Profiles().Lend(context, host);
  }
}

bool Exposes(content::DevToolsAgentHost* agent_host) {
  const Choice& choice = CurrentChoice();
  if (!choice.requested || agent_host->GetType() == content::DevToolsAgentHost::kTypeBrowser) {
    return true;
  }
  content::BrowserContext* context = agent_host->GetBrowserContext();
  if (!choice.valid || !context) {
    return false;
  }
  if (IsContext(context)) {
    return true;
  }
  Profile* chosen = choice.ephemeral ? nullptr : EngineBinding::Get().Profiles().Find(choice.profile);
  if (!chosen || chosen->IsOffTheRecord() || context != chosen) {
    return false;
  }
  if (choice.all_tabs) {
    return true;
  }
  content::WebContents* contents = agent_host->GetWebContents();
  return contents && IsOpened(contents, 0);
}

void MarkOpened(content::WebContents* contents) {
  if (contents && CurrentChoice().requested) {
    Mark(contents->GetOutermostWebContents());
  }
}

ScopedOpening::ScopedOpening() {
  ++CurrentState().opening;
}

ScopedOpening::~ScopedOpening() {
  --CurrentState().opening;
}

}  // namespace crest::automation
