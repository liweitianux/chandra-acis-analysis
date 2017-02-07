#!/usr/bin/env python3
#
# Shuffle the profile data point values according to their errors.
#
# Weitian LI
# 2017-02-07

import sys
import numpy as np


if len(sys.argv) != 3:
    print("Usage: %s <input_profile> <shuffled_profile>")
    sys.exit(1)


# 4-column data: radius, err, temperature/brightness, err
data = np.loadtxt(sys.argv[1])

x1 = data[:, 2]
xe = data[:, 3]
x2 = np.zeros(shape=x1.shape)

for i in range(len(x2)):
    if x1[i] <= 0 or xe[i] <= 0:
        # Skip shuffle
        x2[i] = x1[i]

    v = -1.0
    while v <= 0:
        v = np.random.normal(0.0, 1.0) * xe[i] + x1[i]
    x2[i] = v

# Replace original values
data[:, 2] = x2

np.savetxt(sys.argv[2], data)
