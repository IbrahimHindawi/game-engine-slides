---
marp: true
theme: default
class: invert
---

# Demystifying Game Engines
By: Ibrahim El Hindawi

---

*"I made up the term "object-oriented," and I can tell you I did not have C++ in mind."*
- Alan Kay

*"Object-oriented programming is an exceptionally bad idea which could only have originated in California."*
- Edsger W. Dijkstra

*"You wanted a banana but what you got was a gorilla holding the banana and the entire jungle."*
- Joe Armstrong

---

# Outline
- Game Engine Architecture Overview
- Subsystems: Input, Update, Render, Audio, Time
- C & Assembly Implementation Details

---

# Prologue

---

# **ULTRA-MINIMALISM**:
*"Simplicity is the ultimate sophistication"*
We want to simplify everything as much as humanly possible!
From the compiler to the language to the systems to the generated machine code.
This will be our design philosophy!

---

# Why build a Game Engine:
- Joy of Programming
- Unreal Engine has 20 million lines of incomprehensibly complicted C++
- Unity is closed source and uses C# (Garbage Collector Pauses)
- DotS/MASS is quite new and experimental and feel like they're shoehorned into the engine
- Too fat, too bulky, too slow to work in, even if output is optimal

---

# Why NOT build a Game Engine:
Commercial Engines are great if you:
- have an army of devs & artists
- have to target multiple platforms quickly and reliably
- don't want tech debt & maintenance costs

---

# Forget "Engine", we just want a Game!
For my game, I'm a DotA 2 player & I like roguelikes.
I want to make an ARPG Rogue-like.
I don't want to build an ultra generic cosmic do-it-all engine at all!
Requirements:
- top down camera
- spells & cooldowns
- buffs/debuffs
- randomized upgrades
- randomized levels

---

# I - Game Engine Architecture Overview

---

# AAA Game Engine Architecture:
![bg left fit](arch.png)
- many generic subsystems
- huge complexity
- many requirements
- likely to have high compile times
- harder to iterate

---

# Handmade Game Engine Architecture:
![bg right fit](miniarch.png)
- tiny codebase
- highly specialized
- one target
- super fast compile times
- highly agile

---

# II - Game Engine Subsystems

---

# Resource Allocation
All resources are allocated at game start.
```c
enum ResourceMeshSkinId {
    resource_meshskin_g,
    resource_meshskin_goat,
    resource_meshskin_d,
    resource_meshskin_count,
};
ModelSkin ModelSkinDataArray[resource_meshskin_count];
```

---

Data Oriented Design is all about (but not restricted to) data layouts and optimal memory read/writes.
Basically SoA vs AoS: Struct of Arrays vs Array of Structs.
```c
// AoS
struct entity { vec3 pos; vec3 vel; vec3 torque; vec3 color; };
array<T> entities;
entities[0].pos = {};
```
VS
```c
// SoA
struct entity_payload { array<vec3> pos; array<vec3> torque; array<vec3> color; };
entity_payload entities;
entities.pos[0] = {};
```

---

# Archetype based Entity Component System

```c

struct GameState {
    Array_vec3s positions;
    Array_vec3s velocities;
    Array_vec3s rotations;
    Array_vec3s scales;
    Array_f32 speeds;
    Array_u32 shapes;
};

struct StaticArchetype {
    GameState gamestate;
    GfxState gfxstate;
    DebugState dbgstate;
    EntityData entity_data;
};
```

---

# Data Oriented Design

Entities are just IDs, indices into arrays.
EntityHero is just 0.
```c
entity_payload->dbgstate.vaos.data[EntityHero] = 
    MeshDataArray[resource_mesh_circle].vao;
```

---

# Core Loop
```c
int main() {
    subsystems_initialize_all();
    resource_load_all();
    set_initial_state();
    while (game_is_running) {
        input_read();
        update();
        render();
    }
}
```

---

# Core Loop With Framerate
https://gafferongames.com/post/fix_your_timestep
```c
int main() {
    subsystems_initialize_all();
    resource_load_all();
    set_initial_state();
    while (game_is_running) {
        if (!should_wait()) { // check target framerate
            input_read();
            update();
            render();
        } else {
            sleep(time_to_wait);
        }
    }
}
```


---

# Input Subsystem
![bg left fit](input.png)
https://www.youtube.com/watch?v=-z8_F9ozERc

---

```c
void input_read() {
    while (os_get_event()) {
        switch (event) {
            case QUIT: {
                game_is_running = false;
            }
            case KEY_PRESSED: {
                if (vkcode == ESCAPE) {
                    running = false;
                } else if (vkcode == 'W') {
                    player_velocity.x += 1.f;
                } else if (vkcode == 'S') {
                    player_velocity.x -= 1.f;
                } else if (vkcode == 'A') {
                    player_velocity.y += 1.f;
                } else if (vkcode == 'D') {
                    player_velocity.y -= 1.f;
                } else if (vkcode == SPACE) {
                    shoot();
                }
            }
        }
    }
}
```

---

# Update:
Here is where all the core game logic & physics gets updated.

## Core Game Simulation:
- update input stimulus
- update state machines
- update animations
- compute physics
- compute gpu data (model matrices/uniforms)

---

# Game Simulation:
You basically wanna create "The Big Bang" and have everything stem out from that.
*t0* is when all the game state is initialized to meaningful values so that the simulation can carry forward.
It is basically an accumulative function that keeps updating state into infinity taking the previous into consideration.
```
t0       t1       t2       t3       ...
+--------+--------+--------+--------+---
```
It is basically just:
input -> system -> output

---

# The Big Bang (Entity Initialization):
*t0* happens after all entities are set good defaults:
- A vector might have `{0,0,0}` as a start position to become `{0,1,0}` after physics integration.
- A entity's state might have `state_idle` as a starting state and then mutate to become `state_action`.
- A color might have `{0,0,0}` and then become `{1,0,0}` after some system stimulus.

Hence the simulation will wait for specific stimuli from players/AI to compute the next frame which is *t1* in this case.

---

# State Machine & Stimulus:
After Entity Initialization, the state machine will only react to the input stimuli:
- player controller feeds stimuli to player
- code logic feeds stimuli to enemy entities
- the game clock feeds stimuli to time of day rendering (day/night)

```c
input_read(); // get stimulus
for (i32 i = 0; entity_payload.length; ++i) {
    switch (entity_payload->actionstate.data[i]) {
        case action_attack: {
            entity_payload->actionstate.data[i] = action_attack;
        } break;
        case action_magic: {
            entity_payload->actionstate.data[i] = action_magic;
        } break;
    }
}
```

---

# State Persistence:
It starts to get tricky when you want some state to propagate across many frames.
My solution was to set booleans that engage/disengage after a certain number of frames.
```c
Action action_stimulus; // state
bool action_in_flight; // block other actions
bool action_actuated; // action has terminated
```
And then had to add tight coupling with the animation system:
```c
f32 actiontime;
f32 actionreset;
```

---

# Action State Fragment:
Ended up with an Action State Fragment setup:
```c
struct ActionStateFragment {
    Animation animationclip;
    f32 animationcliptime;
    f32 animationclipframetime;
    bool canmove;
    bool canrotate;
    DamageType damagetype;
};
struct ActionStatePayload {
    Array_ActionStateFragment actionstatefragments;
};
```

---
# Declarative Action State:
```c
entity_payload->actionstate.actionstatepayloads.data[EntityHero].actionstatefragments.data[ActionMain] = 
    actionstatefragmentInitialize(AnimationDataArray[resource_anim_goat_main], false, false, DamageCleave);

entity_payload->actionstate.actionstatepayloads.data[EntityHero].actionstatefragments.data[ActionSpecial] = 
    actionstatefragmentInitialize(AnimationDataArray[resource_anim_goat_magic], false, false, DamageCleave);

entity_payload->actionstate.actionstatepayloads.data[EntityHero].actionstatefragments.data[ActionDefense] =
    actionstatefragmentInitialize(AnimationDataArray[resource_anim_goat_shout], false, false, DamageCleave);

entity_payload->actionstate.actionstatepayloads.data[EntityHero].actionstatefragments.data[ActionDash] = 
    actionstatefragmentInitialize(AnimationDataArray[resource_anim_goat_dash], false, false, DamageNone);
    
entity_payload->actionstate.actionstatepayloads.data[EntityHero].actionstatefragments.data[ActionPower] = 
    actionstatefragmentInitialize(AnimationDataArray[resource_anim_goat_power], false, false, DamageCleave);

entity_payload->actionstate.actionstatepayloads.data[EntityHero].actionstatefragments.data[ActionTrait] = 
    actionstatefragmentInitialize(AnimationDataArray[resource_anim_goat_trait], false, false, DamageRadial);

entity_payload->actionstate.actionstatepayloads.data[EntityHero].actionstatefragments.data[ActionUltimate] = 
    actionstatefragmentInitialize(AnimationDataArray[resource_anim_goat_ultimate], false, false, DamageRadial);
```
---

# Declarative Action State Integration:
```c
actionstateIntegrate(i, &entity_payload->actionstate, ActionMain);
```

---

# Physics:
I was going to build a 3D physics engine 😅 but then realized my game only needs 2D physics:
```c
void collideCircles(GameState *gamestate, i32 entity_a, i32 entity_b);
void collide_circles_single(GameState *gamestate, i32 entity_a, i32 entity_b);
void collideBoxesSystem(GameState *gamestate, i32 entity_a, i32 entity_b);
void collide_circles_boxes_single(GameState *gamestate, i32 entity_a, i32 entity_b);
void collideCirclesSystem(GameState *gamestate_a, i32 entity_a, GameState *gamestate_b, i32 entity_b);
void collide(GameState *gamestate_a, i32 entity_a, GameState *gamestate_b, i32 entity_b);
void collideCircleBoxesSystem(GameState *gamestate_a, i32 entity_a, GameState *gamestate_b, i32 entity_b);
```

---

# There's no escape:
You'll end up writing something like this in your favorite game engine anyway for your game logic!
It is worth taking the time to dive into state machines since this will be the heart and soul of the game.
(Unreal does have GAS Gameplay Ability System)

---

# Render:
My renderer is dead simple:
- update matrices
- update uniforms
- render everything

---
```c
for (i32 i = 0; i < ButtonCount; ++i) {
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, guibuttons_archetype->gui_buttons_state.textures.data[i]);
    glUseProgram(ShaderDataArray[resource_shader_action].id);

    glUniform4f(shaderUniformGet(&memory->permanent, &ShaderDataArray[resource_shader_action], "Color"), 1.0f, 1.0f, 1.0f, 1.0f);
    glUniform1f(shaderUniformGet(&memory->permanent, &ShaderDataArray[resource_shader_action], "normalized_value"), gpubuffer_buttons_state[i] / gpubuffer_buttons_max_state[i]);
    glUniformMatrix4fv(shaderUniformGet(&memory->permanent, &ShaderDataArray[resource_shader_action], "model"), 1, GL_FALSE, &guibuttons_archetype->gui_buttons_state.models.data[i].m00);
    // glUniformMatrix4fv(shaderUniformGet(&memory->permanent, &ShaderDataArray[resource_shader_action], "model"), 1, GL_FALSE, &entity_payload->gfxskinstate.models.data[EntityHero].m00);
    glUniformMatrix4fv(shaderUniformGet(&memory->permanent, &ShaderDataArray[resource_shader_action], "view"), 1, GL_FALSE, &view.m00);
    glUniformMatrix4fv(shaderUniformGet(&memory->permanent, &ShaderDataArray[resource_shader_action], "proj"), 1, GL_FALSE, &proj.m00);

    glBindVertexArray(MeshDataArray[resource_mesh_sprite].vao);
    glDrawElements(GL_TRIANGLES, MeshDataArray[resource_mesh_sprite].indices_count, GL_UNSIGNED_INT, 0);
}
```
---

# III - C & Assembly Implementation

---

![bg right fit](memhier.png)
# The Machine:
## Deeper dive into the Hardware Architecture.

---

# The Memory Wall:
- CPUs are actually fast but memory is slow.
- CPU designers mitigate the slow memory reads on x86-64/ARM64 machines by giving them cache memory (L1, L2, L3).
- CPU have also had SIMD (Single Instruction Multiple Data) registers for quite a long time (XMM0 YMM0 ZMM0).

---


# Vectorization
CPUs have registers that are basically tiny but ultra-fast memory.
| 64  | 32   | 16    | 8      | name            |
|-----|------|-------|--------|-----------------|
| rax | eax  | ax    | ah/al  | accumulator     |
| rbx | ebx  | bx    | bh/bl  | base            |
| rcx | ecx  | cx    | ch/cl  | counter         |
| rdx | edx  | dx    | dh/dl  | data            |

---

# Vectorization
CPUs also have wide registers that allow for parallel processing (SIMD):
| 512 | 256  | 128  |
|-----|------|-------
| ZMM | YMM  | XMM  |

---

# Vectorization
128 bit/16 byte
```
f32     |f32     |f32     |f32
x       |y       |z       |w
00000000|00000000|00000000|00000000
```

```x86asm
; load a[0..3] into xmm0
movaps xmm0, [rax]      ; aligned load  (use movups if unaligned)

; load b[0..3] into xmm1
movaps xmm1, [rbx]

; add element-wise (a + b)
addps xmm0, xmm1        ; xmm0 = xmm0 + xmm1 (4 floats added in parallel)

; store the result to c[0..3]
movaps [rcx], xmm0
```

---

# Cache Coherence

When you load a byte, the CPU pre-fetcher will cache the next 64 bytes into the L1 cache.
So packing things thighly in memory yields significant performance advantages and unlocks vectorization.
```
load byte
v
0000000000000-000000000000-000000000000-000000000000
+------------+------------+------------+------------
^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~cached entire line
```

---

# Why C?
C is transparent and feels like Assembly, which is actually what we want to be writing.
- simple language if you love assembly
- clear delineation between static/stack/heap memory
- has so much tooling (ide lsp dbg san)
- everyone must speak C
- highly portable
- timeless
- unsafe

---

# Memory Allocation Strategy:
Arena Allocators all the way:
Free-list allocators (malloc/new) spread allocations all over RAM.
Pre-allocate 4096 bytes i.e. 1 page and use that memory to allocate objects, allocate more if needed.
Arena Allocators are the core to build many allocators on top of, they also trivialize memory management.
https://www.gingerbill.org/series/memory-allocation-strategies/
https://www.rfleury.com/p/untangling-lifetimes-the-arena-allocator
https://github.com/ibrahimhindawi/saha

---

# Arena Allocator
save the base position
```
+----+----+----+----+----+----
^base
```

increment pointer to allocate
```
+----+----+----+----+----+----
^base          ^alloc
```

reset the position to free
```
+----+----+----+----+----+----
^base
```
---

```c
struct T { u32 a; u32 b; };

struct array_T {
    u64 length;
    u64 capacity;
    T *data;
};

int main() {
    Arena arena = {};
    arenaInitialize(&arena);
    void *pos = arenaGetPos(&arena); // save position
    array_T ts = { .length = 16 };
    ts.data = arenaPushArrayZero(&arena, T, ts.length); // alloc
    for(i32 i = 0; i < ts.length; i++) {
        ts.data[i].a = i;
        ts.data[i].b = i;
    }
    arenaSetPos(&arena, pos); // dealloc
    return 0;
}
```
---

# Generic Data Structures:
https://github.com/ibrahimhindawi/haikal
Code Gen'd generic data structures, highly hackable, highly debuggable:
- Read data structure file
- Replace `TYPE` with your type
- Save and compile file
```c
struct array_TYPE { TYPE *data; u64 length; u64 capacity };
```
Becomes:
```c
struct array_i32 { i32 *data; u64 length; u64 capacity };
```
Done!

---

# Assembly:
https://github.com/ibrahimhindawi/masm64-init
https://github.com/ibrahimhindawi/vulkasm
You don't have to write everything in assembly, but being able to read assembly helps tremendously:
- Intimate understanding of the machine.
- Debug abilities.
- Optimization abilities.
- Undertand Interpreters/Compilers

---

# Epilogue

---

# Dare to dream!
Don't be afraid of the machine, conquer it!
Don't hide behind 18 septillion abstractions, understand them!
Don't rely on gigantic libraries, build them!

---

Discord: x19
Github: github.com/ibrahimhindawi
Linktree: linktr.ee/ibrahimhindawi

---

# Some Code:
```x86asm
.data
n qword ?
.code
main proc
 xor rax, rax
 ret
main endp
```
---
