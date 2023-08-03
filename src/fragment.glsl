precision mediump float;
varying vec2 v_texCoord;
uniform vec2 u_size;
uniform sampler2D u_image;


// Full optical flow will enable searching of blocks of any xy displacement within the neighborhood.
// If full optical flow is disabled, only blocks that are displaced along x will be considered.
// This second option is useful for stereo vision applications.
//#define FULL_OPTICAL_FLOW


#define NOISE_STRENGTH 0.1
#define BORDER_THRESHOLD 3.0

#define MAX_DISPLACEMENT 32
#define BLOCK_SIZE_PX 7
#define BLOCK_DISPLACEMENT_QUANTUM_PX 3
#define MAX_DEPT_MM 3000.

const vec3 ones = vec3(1., 1., 1.);
const int interBlockOffsetAmount = (BLOCK_SIZE_PX - 1) / 2;
const float blockSizeSquared = float(BLOCK_SIZE_PX * BLOCK_SIZE_PX);
const float infinity = 1e10;

// Ridge kernel for edge detection
const mat3 kernel = mat3(
    -1.0, -1.0,  -1.0,
    -1.0,  8.0, -1.0,
    -1.0, -1.0,  -1.0
);

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453) - 1.;
}

float computeEdgeBrightness(vec2 texCoord) {
    // TODO: Should be global but GLSL keeps bitching around
    float texelSize = float(BORDER_THRESHOLD) / u_size.x;
    vec3 edge = vec3(0.0);

    for (int i = -1; i <= 1; i++) for (int j = -1; j <= 1; j++) {
        vec2 offset = vec2(float(i), float(j)) * texelSize;
        vec4 neighbor = texture2D(u_image, texCoord + offset);
        edge += neighbor.rgb * kernel[i + 1][j + 1];
    }

    return (edge.r + edge.g + edge.b) / 9.;
}

// Calculates the dissimilarity between two blocks using Mean Squared Error
float computeBlockError(vec2 blockPositionA, vec2 blockPositionB) {
    float mse = 0.;

    // Displacement of pixels within blocks
    for (int n = -interBlockOffsetAmount; n < interBlockOffsetAmount; n++)
    for (int m = -interBlockOffsetAmount; m < interBlockOffsetAmount; m++) {
        vec2 pixelDisplacement = vec2(float(n) / u_size.x, float(m) / u_size.y);
        vec2 pixelPositionA = blockPositionA + pixelDisplacement;
        vec2 pixelPositionB = blockPositionB + pixelDisplacement;

//                    if (pixelPositionB.x < 0.5 || pixelPositionB.x >= u_size.x ||
//                        pixelPositionB.y < 0.0 || pixelPositionB.y >= u_size.y ||
//                        pixelPositionA.x < 0.0 || pixelPositionA.x >= u_size.x / 2.0 ||
//                        pixelPositionA.y < 0.0 || pixelPositionA.y >= u_size.y) continue;

        vec3 pixelA = texture2D(u_image, pixelPositionA).rgb;
        vec3 pixelB = texture2D(u_image, pixelPositionB).rbg;

        // Significant optimization potential:
        //   Grayscale needs not be calculated every time!
        mse += pow(dot(pixelB - pixelA, ones), 2.);
    }

    return mse / blockSizeSquared;
}

/**
 * Returns a vector with the displacement in XY to closest block match between
 * the block at texCoordA and texCoordB.
 * This function thus represents a vector field the describes the optical flow between
 * two relating images.
 */
vec2 computeXYDisplacement(vec2 texCoordA, vec2 texCoordB) {
    float lowestFoundBlockError = infinity;
    vec2 bestFoundMatch = vec2(0, 0);

    for (int i = -MAX_DISPLACEMENT; i <= MAX_DISPLACEMENT; i += BLOCK_DISPLACEMENT_QUANTUM_PX)
    for (int j = -MAX_DISPLACEMENT; j <= MAX_DISPLACEMENT; j += BLOCK_DISPLACEMENT_QUANTUM_PX) {
        if (i == 0 && j == 0) continue;

        vec2 blockDisplacement = vec2(float(i) / u_size.x, float(j) / u_size.y);
        vec2 blockPositionA = texCoordA;
        vec2 blockPositionB = texCoordB + blockDisplacement * float(BLOCK_SIZE_PX);

        float blockError = computeBlockError(blockPositionA, blockPositionB);

        // Update best match if new lowest block error found
        if (blockError < lowestFoundBlockError) {
            lowestFoundBlockError = blockError;
            bestFoundMatch = blockDisplacement;
        }
    }

    return bestFoundMatch / float(MAX_DISPLACEMENT);
}

// Similar to computeXYDisplacement() but only along X-axis
float computeXDisplacement(vec2 texCoordA, vec2 texCoordB) {
    float lowestFoundBlockError = infinity;
    vec2 bestFoundMatch = vec2(0, 0);

    // Displacement of blocks within texture
    //   IMPORTANT for stereo vision: Only displace blocks along the x axis,
    //   Any displacement along y is essentially noise.

    for (int i = -MAX_DISPLACEMENT; i <= MAX_DISPLACEMENT; i += BLOCK_DISPLACEMENT_QUANTUM_PX) {
        if (i == 0) continue;

        vec2 blockDisplacement = vec2(float(i) / u_size.x, 0);
        vec2 blockPositionA = texCoordA;
        vec2 blockPositionB = texCoordB + blockDisplacement * float(BLOCK_SIZE_PX);

        float blockError = computeBlockError(blockPositionA, blockPositionB);

        // Update best match if new lowest block error found
        if (blockError < lowestFoundBlockError) {
            lowestFoundBlockError = blockError;
            bestFoundMatch = blockDisplacement;
        }
    }

    return bestFoundMatch.x / float(MAX_DISPLACEMENT);
}

float computeDepth(float disparity) {
    const float baseLine = 120.;
    const float focalLength = 4.32;
    return (baseLine * focalLength) / disparity;
}

vec3 edgeDetectionWithContrast(vec2 texCoord) {
    vec4 raw_color = texture2D(u_image, texCoord);

    float edgeBrightness = computeEdgeBrightness(texCoord);
    float r = raw_color.r / 2. + edgeBrightness * 3.;
    float g = 0.;
    float b = raw_color.b;

    // Amplifies red/blues
    if (r > b) b -= r;
    else r -= b;

    return vec3(r, g, b);
}

void main() {
    vec2 texCoordA = vec2(v_texCoord.x / 2., v_texCoord.y);
    vec2 texCoordB = vec2(v_texCoord.x / 2. + 0.5, v_texCoord.y);

//    vec3 highContrastEdges = edgeDetectionWithContrast(texCoordA);
//    vec3 displacement = vec3(computeDisplacement(texCoordA, texCoordB) * 1000., 0.0);
    float disparity = computeXDisplacement(texCoordA, texCoordB);
    float depth = computeDepth(disparity);
//    vec3 modified_color = (vec3(depth * .00001) + highContrastEdges * 0.3) / 3.;
    vec3 modified_color = vec3(depth * 0.001);

    gl_FragColor = vec4(modified_color, 1.);
}
