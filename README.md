# [![Godot-Roc](brand/logo-stroke.plain.svg)](https://github.com/scottc/godot-roc)

GDExtension Roc language bindings generator for Godot Game Engine, Redot Game Engine & Blazium Game Engine.

> [!NOTE]   
> For **game development** with godot-roc see our [Getting Started Example](https://github.com/scottc/survivepg).
>
> This page is for the godot-roc **platform generator**.

## About

Godot-Roc lets you write game logic in [Roc](https://roc-lang.org/), "A [fast](https://roc-lang.org/fast), [friendly](https://roc-lang.org/friendly), [functional](https://roc-lang.org/functional) language". While [Godot Engine](https://godotengine.org/), [Redot Engine](https://www.redotengine.org/) or [Blazium Engine](https://blazium.app/) handles scenes, rendering, and tooling.

game engine/s <-> zig host runtime <-> roc platform APIs <-> game development experience

## Demo

Live web wasm32-emscripten demo:

- [godot-demo](https://scottc.github.io/godot-roc)
- [redot-demo](https://scottc.github.io/redot-roc)

![Godot-Roc Screenshot](brand/Screenshot_20260923_194128.png)

The binding generator will allow for multi-engine & multi-version projects, which can help facilitate engine migration or games targeting an array of engines. As well as custom trimmed down APIs for "just my use-case", for example a 2D project where you don't need 3D apis.

## Binding Generator Status - 2026-10-10

> Snapshot of the **godot-roc** binding generator (from `extension_api.json`).  
> Status is intentionally conservative so new users can see what’s real vs. stubbed.

| Area | Status | Notes |
|------|--------|-------|
| **Engine support** | Partial | Godot 4.x primary. Multi-engine tags exist (`Godot4.7`, `Godot4.3`, `Redot26.2`, `Blazium0.6`) but runtime/compile selection is still partially hardcoded. |
| **Engine version** | Godot 4.7 (header-driven) | `EngineInfo` is generated from the dumped `extension_api.json` header (`version_major/minor/patch` + full name). Platform identity currently fixed as `Godot4.7`. |
| **Roc API availability** | High (surface) | Full generation of: Host signatures, GlobalConstants, GlobalEnums, BuiltinClassSizes/MemberOffsets, NativeStructures, UtilityFunctions, math value types, builtin classes, Object classes, singletons, and platform `main.roc`. |
| **Zig stubs** | Yes (non-simple) | Methods / utility functions that are **vararg** or use non-wireable types fall back to stub bodies (`return 0` / `zeroes` / `undefined`). |
| **Functioning Zig implementations** | Partial (simple path) | Live for **simple** signatures: scalars (`bool`/`int`/`float`/`double`/`void`), `String`/`StringName`/`NodePath`, and math struct builtins. Uses `callBuiltin` / `callInstance` / `callUtility` + singleton lookup. |
| **CpuArch–OS support** | Partial | Declared platform targets: `x64musl`, `wasm32`, `x64win`, `arm64win`, `x64mingw`, `arm64mingw`. CI currently exercises **x64musl** (desktop `.so`) and **wasm32** (web GDExtension) most thoroughly. |
| **Gameplay surface** | Minimal viable | Platform hooks: `scene_init!`, `ready!`, `process!`, `physics_process!`. Facade: `register_class!`, `print_error!`, `print_warning!`, `engine_runtime_ok!`, `target_engine!`. Math types are usable; most class/builtin methods are exposed in Roc and work when they hit the simple Zig path. |
| **Properties** | Comment-only | Generated as documentation comments (getter/setter names). No dedicated Roc property accessors yet. |
| **Signals** | Comment-only | Generated as documentation comments. No connect/emit surface yet. |
| **Enums / bitfields** | Roc types + int ABI | Enums appear as Roc tag unions where generated; ABI side often collapses to `I64`/`i64`. |
| **Variant / containers** | Opaque handles | `Variant`, `Array`, `Dictionary`, packed/typed arrays, `RID`, `Callable`, `Signal` → `U64` / `u64` handles (no high-level Roc API yet). |
| **Overall completeness** | **~35–45%** (MVP) | Strong **codegen + type surface** and a working **simple-call path**. Not yet a full Godot scripting experience (properties, signals, complex types, multi-engine, broad OS matrix). |

### Legend

| Symbol | Meaning |
|--------|---------|
| **High** | Generated and intended for use |
| **Partial** | Present but incomplete / limited paths |
| **Stub** | Signature exists; body is placeholder |
| **Comment-only** | Documented in Roc, not callable yet |

### What works today (practical)

- Generate Roc + Zig ABI from a Godot `extension_api.json`
- Math value types (`Vector2`…`Color`, transforms, etc.) with matching Zig layouts
- Call **simple** builtin/class/utility methods through the host
- Register classes and run the basic game loop callbacks
- Build **Linux (x64musl)** and **Web (wasm32)** paths in CI

### What’s next (high impact)

1. Widen Zig wiring beyond “simple” types (Variant, arrays, objects as first-class)
2. Properties + signals as real Roc APIs
3. True multi-engine / multi-version selection (drop hardcoding)
4. Broader CpuArch–OS validation (Windows ARM/x64, etc.)
5. Replace remaining stubs with real `ptrcall` / vararg paths

## Binding comparison

> [!IMPORTANT]   
> This project is under development, and there are missing or incomplete features.

| | godot-roc | GDScript | C# | C++ |
| --- | --- | --- | --- | --- |
| **API coverage** | \[WIP] [[DONE-engine-to-zig-binding-generator](scripts/gdextension_interface.generate.roc)] [[WIP-engine-to-roc-binding-generator](scripts/extension_api.generate.roc)] \[TODO-docs] | Full engine scripting API | Broad official bindings | Full native access |
| **Native desktop support** | Linux (\[WIP] cross-compiling; windows & macos) | Linux, windows & mac | Linux, windows & mac | Linux, windows & mac |
| **Web support** | GDExtension wasm (emscripten) | First-class, full | Not supported (official) | GDExtension wasm (emscripten) |
| **Role in Godot** | Community binding (this project) | First-party script language | Official .NET support | Engine / GDExtension native |

## Language & Compiler comparison

> [!NOTE]
> *This table is intentionally simplified. Real projects can mix languages (e.g. GDScript for UI + Roc or C# for gameplay + C++ for hotspots).*
>
> [Other community maintained languages](https://docs.godotengine.org/en/stable/tutorials/scripting/other_languages.html#doc-scripting-languages), and [engines](https://docs.redotengine.org/tutorials/scripting/gdextension/what_is_gdextension#doc-what-is-gdextension) are also avaliable.

| | Roc | GDScript | C# | C++ |
| --- | --- | --- | --- | --- |
| **Iteration speed in Godot** | Fast native rebuild & reload pipeline. 1 class ~=250/300ms(cache/no-cache) on my potato laptop | Very fast | Fast | Slow–moderate (compile native) |
| **Learning curve** | [Easy-moderate](https://roc-lang.org/friendly) (if new to FP) | Easy | Moderate | Hard |
| **Performance potential** | [High](https://roc-lang.org/fast) (native extension path) | Good enough for most games | High | Highest (engine-level) |
| **Skills transfer outside Godot** | Yes (general Roc / FP) | Limited | Yes | Yes |
| **Primary style** | ✨[**Functional**](https://roc-lang.org/functional)✨ | Multi-paradigm, script-oriented | Multi-paradigm | Multi-paradigm |
| **Type system** | ✨**Strong, static, inference**✨ | Optional / gradual | Static (nullable & pragmatism) | Static (manual discipline) |
| **Ecosystem maturity** | New [[projects](https://github.com/lukewilliamboswell/roc-awesome)] | Mature (Godot-focused) | Mature | Mature |
| **Docs & tutorials** | Offical Language docs [[roc-docs](https://roc-lang.org/docs/main/)] [[roc-examples](https://roc-lang.org/examples/)] & emerging community | Official & plentiful | Official + .NET ecosystem | Official engine docs; steeper |

## Performance Profile

> [!NOTE]
> GDScript runs on a bytecode VM and is not compiled to native machine code for
> gameplay scripts. In Godot 4, typed GDScript is faster than untyped, but tight
> pure-script loops still lag C#/C++. Roc in godot-roc is compiled to native code
> and the host is Zig (also native) loaded as a GDExtension—there is no Roc VM in
> the game loop. For all of these, much gameplay work is ultimately engine C++
> (physics, rendering), so language choice often does not dominate frame time
until profiling shows a script/app-side hotspot.

| | Roc (godot-roc) | GDScript | C# | C++ / GDExtension |
|--|-----------------|----------|-----|-------------------|
| **Execution model** | [Native](https://roc-lang.org/fast) (Roc → machine code; [Zig](https://ziglang.org/) host in a GDExtension) | Bytecode on Godot’s VM | .NET (JIT/AOT depending on setup) | Native |
| **Pure number crunching** | High (native) | Slowest of these | Usually much faster than GDScript | Fastest / engine-level |
| **Calling into Godot APIs** | Native extension path (ptrcall / binds); not free if very chatty | Very direct (language designed for this) | Can pay marshalling costs | Direct native |
| **Small, API-heavy glue** | Fine; bound by engine + bind overhead | Often “fast enough”; very low friction to engine | Marshalling can dominate tiny calls | Fast, but awkward for large amounts of glue |
| **Heavy algorithms in script/app code** | Strong fit | Prefer not to keep in pure GDScript | Strong option | Best option |
| **Typical game bottleneck** | Often still rendering / physics / draw calls (engine C++), not Roc vs GDScript | Same | Same | Same unless you replace engine systems |

## Use Cases

- **DX - Developer Experience** - Ergonomics of a high level scripting language, with great low level native performance.

- **Structured game logic** - Model complex rules with types that encode invariants, so invalid states are harder to represent.

- **Fewer playtest bugs** - A strong static type system catches many mistakes at compile time. Good types won’t eliminate playtesting, but they can eliminate many failures.

- **AI-friendly tooling and errors** - More stronger types = more precise compile time errors, that are easier to act on for (humans or automated loops) than vague runtime failures.

## Who is this for?

**Good fit:** experimenters, hobbyists, and people who want to explore Roc for game logic or help shape an early binding.

**Possible but demanding:** beginners and production teams - expect fewer tutorials, a smaller community, and sharper edges than GDScript or C#.

**Not yet:** “drop-in replacement for GDScript to ship a commercial title with zero friction.” If you need that reliability *today*, use Godot’s first-party stack and keep an eye on this project as it matures.

**Right place if:** you like bleeding-edge tooling, are comfortable building against an evolving platform, and care more about typed functional logic than maximum Godot-native convenience.

## When you should strongly consider using godot-roc

You want the ergonomics of a high level scripting language, and 90% of the performance ceiling of a compile to native language. And are whilling to deal with the sharp edges & bugs that comes with latest bleeding edge technology.

## Supporting godot-roc

godot-roc is developed & maintained by a solo dev; me. Here are some things that would greatly help me.

- **Game Dev Testers**, dog fooding small prototypes is one thing. But, I need some game devs, to actually use this project and give me experience reports. Ideally in a complete end-to-end ship game to production environment. What are the blockers? Where are the sharp edges? What could be smoother, faster & more seemless? This can help me prioritize and discover & resolve problems faster.

- **A LLM subscription, or hardware**, unfortunately I don't have access to one... and can't justify one, yet. It could help speed up my progress. Free LLM services, have useage caps; 20 prompts a day or 50k tokens etc. And are only suitable for casual prompting.

- **A source of income**, to pay my bills & rent. At the moment, I'm in the red at the end of every month and this is not sustainable long term. And ideally make a modest living & support my other hobbies; compute/embeded hardware, gadgets etc. If you can afford it, consider donating (when I setup patreon & sponsorships), or give me a job offer for sustainable long-term on-going work.

- **Freedom to continue working on godot-roc**, as how I see fit... For me, I just generally enjoy the process of experimenting with new technology, dealing with new & difficult challenges. And ultimately to serve the needs & desires of game developers & gamers. And I hope that you find this project to be extremely useful.

- **Freedom to move onto the next project**, while this project is great. I eventually see the need to swap out the engine, to a more modern, open-source, high performance design that can out-compete unreal & unity. And the godot-4.5.1 style bindings could be a limiting factor in engine design. As such I have my eyes on the next generation ECS-like engines; bevy and alike.

## Scripts - For platform maintainers.

The scripts folder is for platform generator maintainers, to perform a variety of automated tasks.

> [!IMPORTANT]
> As a platform maintainer, you are expected to robustly handle security & performance.
> 
> As such you are tasked with ensuring a minimal attack surface & performance costs to end users & game developers.
>
> In addition, you are also tasked with handling your own security, so game developers & end users are not compromised by proxy.
>
> There will be some need to automate tasks, like updating engine versions, generating new binding & glue.
>
> You are expected to check the platform, and read and understand the consiqences of each script in their entirely, before running them. Or at least running them inside of an isolated sandbox, where you can protect yourself.
>

## Scripts Overview - For platform maintainers.

- `scripts/ci.roc`: Build orchistration & CI script that is triggered to run on every commit to master branch, to build, test & bundle 'cpu arch x os x engine' matrix; to "continously intergrate" code & ensure software quality, and to publish builds.

- `scripts/gdextension_interface.generate.roc`: Generates zig glue from `gdextension_interface.h`

- `scripts/extension_api.generate.roc`: Generates roc & zig glue from `extension_api.json`

- `roc glue ...`: generates the roc platform ABI glue.

- `scripts/publish.roc`: Bundle & Publish a new tagged github release, nightly & stables.

- `scripts/serve.roc`: To serve 'export to web' projects, so we can run wasm game in a web browser.

## Important tools & commands - For platform maintainers.

- `blueprint update`: Upgrade the dev tools, you'll need to manually upgrade some important pins, see: `Blueprint.roc`.

- `blueprint check`: Check the blueprint.

- `blueprint shell`: Enter the development environment.

## Build & Run Binding Generator - For platform maintainers.

Note: roc blueprint package manager is used to manage environments & tools.

```sh
# nix run github:lukewilliamboswell/roc-blueprint/0.5.0 -- shell
blueprint shell

# nix run github:lukewilliamboswell/roc-blueprint/0.5.0 -- run ci -- \
blueprint run ci \
--baseline=godot4.3 \
--engines=godot-stable,redot-stable \
--targets=x64musl,wasm32 \
--tests=all \
-Doptimize=Debug
```
