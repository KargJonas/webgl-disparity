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