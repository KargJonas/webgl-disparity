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

#define MAX_DISPLACEMENT 15
#define BLOCK_SIZE_PX 3
#define BLOCK_DISPLACEMENT_QUANTUM_PX 1
#define MAX_DEPT_MM 3000.

const vec3 ones = vec3(1., 1., 1.);
const int interBlockOffsetAmount = (BLOCK_SIZE_PX - 1) / 2;
const float blockSizeSquared = float(BLOCK_SIZE_PX * BLOCK_SIZE_PX);
const float infinity = 1e10;

//// Calculates the dissimilarity between two blocks using the Sum of Squares
//float computeBlockError(vec2 blockPositionA, vec2 blockPositionB) {
//    float ss = 0.;
//
//    // Displacement of pixels within blocks
//    for (int n = -interBlockOffsetAmount; n < interBlockOffsetAmount; n++)
//    for (int m = -interBlockOffsetAmount; m < interBlockOffsetAmount; m++) {
//        vec2 pixelDisplacement = vec2(float(n) / u_size.x, float(m) / u_size.y);
//        vec2 pixelPositionA = blockPositionA + pixelDisplacement;
//        vec2 pixelPositionB = blockPositionB + pixelDisplacement;
//
////                    if (pixelPositionB.x < 0.5 || pixelPositionB.x >= u_size.x ||
////                        pixelPositionB.y < 0.0 || pixelPositionB.y >= u_size.y ||
////                        pixelPositionA.x < 0.0 || pixelPositionA.x >= u_size.x / 2.0 ||
////                        pixelPositionA.y < 0.0 || pixelPositionA.y >= u_size.y) continue;
//
//        vec3 pixelA = texture2D(u_image, pixelPositionA).rgb;
//        vec3 pixelB = texture2D(u_image, pixelPositionB).rgb;
//
//        // Significant optimization potential:
//        //   Grayscale needs not be calculated every time!
//        ss += pow(dot(pixelB - pixelA, ones), 2.);
//    }
//
//    return ss;
//}

// Calculates the dissimilarity between two blocks using Normalized Cross-Correlation (NCC)
float computeBlockError(vec2 blockPositionA, vec2 blockPositionB) {
    float meanA = 0.0;
    float meanB = 0.0;
    float stdDevA = 0.0;
    float stdDevB = 0.0;

    // Compute mean values of the two blocks
    for (int n = -interBlockOffsetAmount; n <= interBlockOffsetAmount; n++) {
        for (int m = -interBlockOffsetAmount; m <= interBlockOffsetAmount; m++) {
            vec2 pixelPositionA = blockPositionA + vec2(float(n) / u_size.x, float(m) / u_size.y);
            vec2 pixelPositionB = blockPositionB + vec2(float(n) / u_size.x, float(m) / u_size.y);

            vec3 pixelA = texture2D(u_image, pixelPositionA).rgb;
            vec3 pixelB = texture2D(u_image, pixelPositionB).rgb;

            meanA += dot(pixelA, ones);
            meanB += dot(pixelB, ones);
        }
    }

    meanA /= blockSizeSquared;
    meanB /= blockSizeSquared;

    // Compute standard deviations of the two blocks
    for (int n = -interBlockOffsetAmount; n <= interBlockOffsetAmount; n++) {
        for (int m = -interBlockOffsetAmount; m <= interBlockOffsetAmount; m++) {
            vec2 pixelPositionA = blockPositionA + vec2(float(n) / u_size.x, float(m) / u_size.y);
            vec2 pixelPositionB = blockPositionB + vec2(float(n) / u_size.x, float(m) / u_size.y);

            vec3 pixelA = texture2D(u_image, pixelPositionA).rgb;
            vec3 pixelB = texture2D(u_image, pixelPositionB).rgb;

            stdDevA += pow(dot(pixelA, ones) - meanA, 2.0);
            stdDevB += pow(dot(pixelB, ones) - meanB, 2.0);
        }
    }

    stdDevA = sqrt(stdDevA / blockSizeSquared);
    stdDevB = sqrt(stdDevB / blockSizeSquared);

    // Compute the normalized cross-correlation
    float ncc = 0.0;
    for (int n = -interBlockOffsetAmount; n <= interBlockOffsetAmount; n++) {
        for (int m = -interBlockOffsetAmount; m <= interBlockOffsetAmount; m++) {
            vec2 pixelPositionA = blockPositionA + vec2(float(n) / u_size.x, float(m) / u_size.y);
            vec2 pixelPositionB = blockPositionB + vec2(float(n) / u_size.x, float(m) / u_size.y);

            vec3 pixelA = texture2D(u_image, pixelPositionA).rgb;
            vec3 pixelB = texture2D(u_image, pixelPositionB).rgb;

            ncc += (dot(pixelA, ones) - meanA) * (dot(pixelB, ones) - meanB);
        }
    }

    ncc /= (blockSizeSquared * stdDevA * stdDevB);

    return 1.0 - ncc; // We want to minimize dissimilarity (1 - NCC).
}

// Computes pixel displacement along x-Axis using block neighbor similarity
float computeXDisplacement(vec2 texCoordA, vec2 texCoordB) {
    float lowestFoundBlockError = infinity;
    vec2 bestFoundMatch = vec2(0, 0);

    // TODO: Potential optimization possible by searching only from x=0 to x=MAX_DISPLACEMENT
    for (int x = -MAX_DISPLACEMENT; x <= MAX_DISPLACEMENT; x += BLOCK_DISPLACEMENT_QUANTUM_PX) {
        vec2 blockDisplacement = vec2(float(x) / u_size.x, 0);
        vec2 blockPositionA = texCoordA;
        vec2 blockPositionB = texCoordB + blockDisplacement * float(BLOCK_SIZE_PX);
        float blockError = computeBlockError(blockPositionA, blockPositionB);

        // Update best match if new lowest block error found
        if (blockError < lowestFoundBlockError) {
            lowestFoundBlockError = blockError;
            bestFoundMatch = blockDisplacement;
        }
    }

    return bestFoundMatch.x * (u_size.x);
}

float computeDepth(float disparity) {
    const float baseLine = 100.;
    const float focalLength = 4.32;

    // For determining the depth map, we are only interested in absolute values of disparity.
    // Havin non-normalized values might however be uesful later on.
    float absoluteDisparity = abs(disparity);
    float depth = (baseLine * focalLength) / absoluteDisparity;

    return depth;
}

void main() {
    vec2 texCoordA = vec2(v_texCoord.x / 2., v_texCoord.y);
    vec2 texCoordB = vec2(v_texCoord.x / 2. + 0.5, v_texCoord.y);

    float disparity = computeXDisplacement(texCoordA, texCoordB);
    float depth = computeDepth(disparity);

    // Estimate the depth range based on the disparity values obtained in the scene.
    // You can manually adjust these values based on your observations.
    const float minDepth = 0.0; // Estimated minimum depth
    const float maxDepth = 100.0; // Estimated maximum depth

    // Clamp the depth value to the specified range (minDepth to maxDepth)
    depth = clamp(depth, minDepth, maxDepth);

    // Normalize the depth value to a 0 to 1 range for visualization
    depth = (depth - minDepth) / (maxDepth - minDepth);

    gl_FragColor = vec4(vec3(1.0 - depth), 1.);
}
