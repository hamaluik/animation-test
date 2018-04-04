#version 450

in vec3 pos;
in vec3 norm;
out vec4 fragColour;

void main() {
    vec3 surfaceToLight = vec3(0, 0, 5) - pos;
    float brightness = dot(norm, surfaceToLight) / (length(surfaceToLight) * length(norm));
    brightness = mix(0.5, 1.0, clamp(brightness, 0, 1));
    fragColour = vec4(vec3(0.27963539958000185, 0.6399999856948853, 0.21094389259815217) * brightness, 1.0);
}
