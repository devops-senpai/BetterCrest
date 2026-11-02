#ifndef CHROME_BROWSER_UI_CREST_CREST_AUTOMATION_H_
#define CHROME_BROWSER_UI_CREST_CREST_AUTOMATION_H_

class Profile;

namespace base {
class CommandLine;
}

namespace content {
class DevToolsAgentHost;
class WebContents;
}  // namespace content

// Browser automation over DevTools remote debugging (Playwright, Puppeteer,
// ChromeDriver), limited to the one Arma profile the person chose.
//
// The person turns it on in Arma's settings, which the app keeps in its own
// defaults (`arma.automation.enabled`, `.port`, `.profile`, `.tabs` and the
// optional `.hostProfile`); the engine reads them once, at startup, and
// declares the remote debugging port and the choices below as switches.
// Remote debugging always listens on the loopback interface only.
//
//   --arma-automation-profile=<profile id>|ephemeral
//       The Arma profile, a Space's `profileID`, automation browses in, or a
//       throwaway off-the-record profile that shares nothing with any Space
//       and is gone when Arma quits.
//   --arma-automation-host-profile=<profile id>
//       The Space whose window shows the pages of an ephemeral profile, and of
//       every browser context DevTools creates. Arma shows a page only in a
//       Space, so these pages join one while keeping their own store.
//       Defaults to the chosen profile, or for an ephemeral one to the Space
//       profile the engine loaded last.
//   --arma-automation-tabs=opened|all
//       Which of the chosen profile's tabs a tool may see: only those it
//       opened (the default), with the pages they open, or every one.
//
// A remote debugging client then sees only those targets: the profile's
// pages, workers and extension contexts as the tab choice allows, and every
// browser context DevTools creates from it. The other profiles' pages are
// absent from `/json/list` and `Target.getTargets` and cannot be attached
// to. Arma's own in-process DevTools clients are never limited.
namespace crest::automation {

// Declares on the browser process's `command_line` what the app's settings
// ask for: `--remote-debugging-port` and the switches above. A switch already
// on the command line wins, so a development launch can override any of
// them. Settings that are off or incomplete declare nothing, so no port opens.
void ApplySettings(base::CommandLine& command_line);

// Whether this launch limits DevTools remote debugging to one Arma profile.
bool IsScoped();

// The profile DevTools uses as its default browser context, loaded now when
// it is a Space's regular profile, or nullptr when the engine has not started
// or the choice names no profile it can load.
Profile* DefaultProfile();

// The profile DevTools derives a new browser context from: the chosen
// regular profile, or for an ephemeral choice the engine's own profile.
Profile* SourceProfile();

// `context` is a browser context DevTools created. Its pages show in the host
// Space and are always exposed.
void AddContext(Profile* context);

// Whether a remote debugging client may see and attach to `agent_host`.
bool Exposes(content::DevToolsAgentHost* agent_host);

// `contents` is a page automation opened. It, and the pages it opens with
// an opener, stay exposed when only opened tabs are.
void MarkOpened(content::WebContents* contents);

// While one exists, a page created in the chosen profile is one automation
// opened. DevTools reports a new page while it is still being created, before
// whoever asked for it can mark it.
class ScopedOpening final {
 public:
  ScopedOpening();
  ScopedOpening(const ScopedOpening&) = delete;
  ScopedOpening& operator=(const ScopedOpening&) = delete;
  ~ScopedOpening();
};

}  // namespace crest::automation

#endif  // CHROME_BROWSER_UI_CREST_CREST_AUTOMATION_H_
