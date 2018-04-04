#version 450

in vec3 position;
in vec3 normal;
in vec4 joints;
in vec4 weights;

uniform mat4 MVP;
uniform mat4 M;
uniform mat4 jointMatrices[2];

out vec3 pos;
out vec3 norm;

void main() {
    mat4 skinMatrix =   weights.x * jointMatrices[int(joints.x)]
                      + weights.y * jointMatrices[int(joints.y)]
                      + weights.z * jointMatrices[int(joints.z)]
                      + weights.w * jointMatrices[int(joints.w)];

    pos = (M * skinMatrix * vec4(position, 1.0)).xyz;
    norm = (M * skinMatrix * vec4(normal, 0.0)).xyz;

    gl_Position = MVP * skinMatrix * vec4(position, 1.0);
}
