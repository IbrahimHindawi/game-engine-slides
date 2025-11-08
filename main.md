---
marp: true
theme: default
class: invert
---

# Demystifying Game Engines
By: Ibrahim El Hindawi

---

Alan Kay: "I made up the term "object-oriented," and I can tell you I did not have C++ in mind."
Dijkstra: "Object-oriented programming is an exceptionally bad idea which could only have originated in California."


---

# Outline
- Game Engine Architecture Overview
- Subsystems: input, update, render, audio, time
- C & Assembly

---

# Why build a Game Engine:
- Unreal Engine has 20 million lines of incomprehensibly complicted C++
- Unity is closed source and uses C#
- DotS/MASS is quite new and experimental
- too fat, too bulky

---

# AAA Game Engine Architecture:
![bg left](arch.png)
This is something  that is for gigantic AAA engines

---

# Game Engine Architecture:
![bg right](arch.png)
This is what you actually need.

---

# Input Subsystem
https://www.youtube.com/watch?v=-z8_F9ozERc

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
```python
print('hell, world!')

```
---
# Dragon Knight
![bg left fit](logo.png)
Is a cool hero
