# Particle Collision Simulation with CUDA
This repository hosts a particle collision simulation implemented in C++ with CUDA support. The simulation is designed to showcase realistic particle interactions within a confined space, including collisions between particles and with the boundaries of the simulation window.

## Why?
This is my attempt to practice cuda now this isnt the best optimization for the long shot and I will be updating it later in the future to further improve it but this is the improvements in fps from my original built of the project to this one.

## Previous 2k Particles
![OldCode-ezgif com-optimize](https://github.com/luis0o2/CudaParticleCollision/assets/59019460/7f5fcf1e-cbc6-428c-93fd-43055e0b8d0e)

## New 2k Particles
![ezgif com-optimize](https://github.com/luis0o2/CudaParticleCollision/assets/59019460/d0683d1b-f27c-4fc4-adee-8376965673c1)

## Features:
Particle Physics: Utilizes CUDA parallel computing to handle particle movement and collision detection efficiently.
Realistic Interactions: Simulates realistic collisions between particles, including elastic collisions and boundary reflections.
User Interaction: Provides user-friendly controls to add, center, and spawn particles, enhancing the interactive experience.
Visual Feedback: Renders particle movements and interactions in real-time using the raylib graphics library, offering visual feedback to the user.
Dynamic Particle Management: Supports dynamic addition, deletion, and manipulation of particles during runtime, allowing for flexible experimentation.
## Technologies Used:
CUDA: Accelerates computation by offloading parallelizable tasks to the GPU, enabling high-performance particle physics simulations.
C++: Implements the core logic of the simulation, leveraging object-oriented programming principles for modularity and maintainability.
raylib: Facilitates graphical rendering and user input handling, providing a lightweight yet powerful framework for game development.
