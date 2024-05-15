#include <vector>
#include <raylib.h>
#include <cmath>
#include <cstdlib>
#include <ctime>
#include <string>
#include <iostream>
#include <cuda_profiler_api.h>

#define SOFTENING 1e-9f

struct Particle {
    float x, y;
    float speedX = 300, speedY = 300;
    float radius = 5;

    Color color = PURPLE;

    void Draw() {
        DrawCircle(x, y, radius, color);
    }
};

__device__ bool CheckCollision(const Particle& p1, const Particle& p2) {
    float dx = p2.x - p1.x;
    float dy = p2.y - p1.y;
    float distanceSquared = dx * dx + dy * dy;
    return distanceSquared <= (p1.radius + p2.radius) * (p1.radius + p2.radius);
}

__device__ void HandleCollision(Particle& p1, Particle& p2) {
    float dx = p2.x - p1.x;
    float dy = p2.y - p1.y;
    float distance = sqrt(dx * dx + dy * dy);
    float nx = dx / distance;
    float ny = dy / distance;
    float tx = -ny;
    float ty = nx;
    float dvx = p2.speedX - p1.speedX;
    float dvy = p2.speedY - p1.speedY;
    float dpNormal = dvx * nx + dvy * ny;
    float imp = (2.0f * dpNormal) / (1 + 1);
    p1.speedX += imp * nx;
    p1.speedY += imp * ny;
    p2.speedY -= imp * ny;
    p2.speedX -= imp * nx;
    float overlap = (p1.radius + p2.radius) - distance;
    p1.x -= overlap * nx * 0.5f;
    p1.y -= overlap * ny * 0.5f;
    p2.x += overlap * nx * 0.5f;
    p2.y += overlap * ny * 0.5f;
    p1.color = RED;
    p2.color = BLUE;
}

__global__ void ParticlePhysics(Particle* particles, float dt, int n, int screenWidth, int screenHeight) {
    int index = threadIdx.x + blockIdx.x * blockDim.x;
    if (index < n) {
        particles[index].x += particles[index].speedX * dt;
        particles[index].y += particles[index].speedY * dt;

        // Border collision detection
        if (particles[index].y - particles[index].radius < 0) {
            particles[index].y = particles[index].radius;
            particles[index].speedY *= -1;
        }
        if (particles[index].y + particles[index].radius > screenHeight) {
            particles[index].y = screenHeight - particles[index].radius;
            particles[index].speedY *= -1;
        }
        if (particles[index].x - particles[index].radius < screenWidth / 5) {
            particles[index].x = screenWidth / 5 + particles[index].radius;
            particles[index].speedX *= -1;
        }
        if (particles[index].x + particles[index].radius > screenWidth) {
            particles[index].x = screenWidth - particles[index].radius;
            particles[index].speedX *= -1;
        }
    }
}
__global__ void ParticleCollision(Particle* particles, float dt, int n) {
    int index = threadIdx.x + blockIdx.x * blockDim.x;
    if (index < n) {

        for (int j = 0; j < n; j++) {
            if (j != index && CheckCollision(particles[index], particles[j])) {
                HandleCollision(particles[index], particles[j]);
            }
        }
    }
}
void AddNewParticle(std::vector<Particle>& particles, Particle*& d_particles) {
    if (IsKeyPressed(KEY_SPACE)) {
        Particle newParticle;
        newParticle.x = GetScreenWidth() / 2.0f;
        newParticle.y = GetScreenHeight() / 2.0f;
        newParticle.speedX = 300;
        newParticle.speedY = 300;
        particles.push_back(newParticle);
        // Resize d_particles and copy data
        cudaFree(d_particles);
        cudaMallocManaged(&d_particles, particles.size() * sizeof(Particle));
        cudaMemcpy(d_particles, particles.data(), particles.size() * sizeof(Particle), cudaMemcpyHostToDevice);
    }
}

void CenterAllParticles(std::vector<Particle>& particles, Particle*& d_particles) {
    if (IsKeyDown(KEY_E)) {
        float centerX = (GetScreenWidth() / 5 + GetScreenWidth()) / 2.0f;
        float centerY = GetScreenHeight() / 2.0f;
        for (int i = 0; i < particles.size(); i++) {
            float dx = centerX - particles[i].x;
            float dy = centerY - particles[i].y;
            float length = sqrt(dx * dx + dy * dy);
            if (length != 0) {
                dx /= length;
                dy /= length;
            }
            particles[i].x += dx * 0.3f;
            particles[i].y += dy * 0.3f;
        }
        // Copy updated particle positions back to d_particles
        cudaMemcpy(d_particles, particles.data(), particles.size() * sizeof(Particle), cudaMemcpyHostToDevice);
    }
}
void Spawn50Particles(std::vector<Particle>& particles, Particle*& d_particles) {
    if (IsKeyPressed(KEY_R)) {
        for (int i = 0; i < 50; i++) {
            int RandomXPos = GetRandomValue(GetScreenWidth() / 2, GetScreenWidth());
            int RandomYPos = GetRandomValue(0, GetScreenHeight());
            Particle newParticle;
            newParticle.x = RandomXPos;
            newParticle.y = RandomYPos;
            newParticle.speedX = 300;
            newParticle.speedY = 300;
            particles.push_back(newParticle);
        }
        // Resize d_particles and copy data
        cudaFree(d_particles);
        cudaMallocManaged(&d_particles, particles.size() * sizeof(Particle));
        cudaMemcpy(d_particles, particles.data(), particles.size() * sizeof(Particle), cudaMemcpyHostToDevice);
    }
}

int main() {
    InitWindow(800, 600, "Particle Collision");
    SetTargetFPS(0);
    std::string add = "Add Particles \n\nPress: Space";
    std::string center = "\n\nCenter Particles \n\nPress: E";
    std::string spawn = "\nSpawn 50 Particles \n\nPress: R";
    std::string pDelete = "Delete Particles\n\nPress: D";

    int deviceId;
    cudaGetDevice(&deviceId);

    cudaDeviceProp props;
    cudaGetDeviceProperties(&props, deviceId);

    int SMs = props.multiProcessorCount;

    std::vector<Particle> particles;
    particles.resize(1);

    Particle* d_particles;
    cudaMallocManaged(&d_particles, particles.size() * sizeof(Particle));

    while (!WindowShouldClose()) {
        size_t threads = 256;
        size_t blocks = SMs * 36;

        float dt = GetFrameTime(); // Adjust as needed
        cudaMemcpy(d_particles, particles.data(), particles.size() * sizeof(Particle), cudaMemcpyHostToDevice);
        AddNewParticle(particles, d_particles);
        CenterAllParticles(particles, d_particles);
        Spawn50Particles(particles, d_particles);

        ParticlePhysics << <blocks, threads >> > (d_particles, dt, particles.size(), GetScreenWidth(), GetScreenHeight());
        ParticleCollision << <blocks, threads >> > (d_particles, dt, particles.size());

        cudaDeviceSynchronize();

        if (IsKeyPressed(KEY_D)) {
            particles.clear();
        }


        cudaMemcpy(particles.data(), d_particles, particles.size() * sizeof(Particle), cudaMemcpyDeviceToHost);

        std::string counter = "Particles: " + std::to_string(particles.size());

        BeginDrawing();
        ClearBackground(WHITE);

        for (int i = 0; i < particles.size(); i++) {
            particles[i].Draw();
        }

        DrawRectangle(0, 0, GetScreenWidth() / 5, GetScreenHeight(), BLACK); //Menu Background
        DrawText(add.c_str(), GetScreenWidth() / 45, GetScreenHeight() / 15, GetScreenHeight() / 40, PURPLE);   //add
        DrawText(center.c_str(), GetScreenWidth() / 45, GetScreenHeight() / 9, GetScreenHeight() / 40, LIME);   //center
        DrawText(spawn.c_str(), GetScreenWidth() / 45, GetScreenHeight() / 4, GetScreenHeight() / 40, ORANGE);	//Spawn
        DrawText(pDelete.c_str(), GetScreenWidth() / 45, GetScreenHeight() / 2.5, GetScreenHeight() / 40, SKYBLUE);	//DELETE PARTICLES
        DrawText(counter.c_str(), GetScreenWidth() / 45, GetScreenHeight() / 2, GetScreenHeight() / 40, GOLD);	//Counter


        DrawFPS(10, 10);
        EndDrawing();
    }

    cudaFree(d_particles);
    CloseWindow();
    return 0;
}