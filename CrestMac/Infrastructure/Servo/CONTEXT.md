# Servo

Arma's Servo engine on the Mac. The engine itself is Rust in
`CrestEngines/Servo` (`libarma_servo.dylib`, built by
`Scripts/build-servo-engine.sh`); this folder loads it at run time and binds
it to the engine port, so a build without the library simply offers no Servo.

## Goal

Host pages on Servo through the same `EngineBinding` port WebKit uses, so the
core moves pages to and from Servo like any other engine.

## Contents

| Path | What it is |
| --- | --- |
| `ServoLibrary.swift` | Loads the library from `ARMA_SERVO_LIBRARY` or the app's Frameworks and resolves its C API |
| `ServoEngine.swift` | The process's one Servo instance: wakes, spins, cookies, user scripts |
| `ServoEngineBinding.swift` | The `EngineBinding`: builds pages, runs the core's commands, reports events |
| `ServoEnginePage.swift` | One page and its desktop adapter: turns Servo's load, address, title and history reports into navigations |
| `ServoEnginePages.swift` | The direct path for page requests; Servo answers reload, every other request answers empty |
| `ServoPageView.swift` | The `NSView` a page draws into, forwarding pointer, wheel and keys |
| `ServoExtension.swift`, `ServoExtensionStore.swift` | Firefox add-ons and unpacked WebExtensions whose content scripts and styles Servo runs as user scripts |

## Rules

- Registration (`BrowserEngineRegistration.servo`) describes what Servo really does; it never becomes the composition's default, only the person's choice.
- Servo's options are global to the process: every profile shares one engine and one store of site data.
- Extensions run only their `content_scripts`; background scripts, popups and `browser` APIs are not available.

## Read next

`../../../CrestShared/Infrastructure/Engines/CONTEXT.md`, then
`../../../CrestEngines/Servo/` for the C API (`ArmaServo.h`).
