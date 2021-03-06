import cv2
import numpy as np
import matplotlib.pyplot as plt
import sys
import math
import argparse
import os

if len(sys.argv) < 3:
    print "Please provide input and output (in that order)."

sh = cv2.imread(sys.argv[1], -1)
out = sys.argv[2]

s = 5
bim = np.zeros((sh.shape[0] + 2, sh.shape[1] + 2), dtype = "float32")

bim[1:-1, 1:-1] = sh[:, :, -1] == 255

bbim = bim * cv2.blur(bim, (3, 3))
xim = bim * cv2.Sobel(bbim, cv2.CV_32F, 1, 0, ksize = 3)
yim = bim * cv2.Sobel(bbim, cv2.CV_32F, 0, 1, ksize = 3)
# Normalize
l = np.sqrt(xim * xim + yim * yim)
v = l > 1e-5
xim[v] = xim[v] / l[v]
yim[v] = yim[v] / l[v]

def dilate_mask(im, mask):
    kernel = np.ones((3,3), dtype = "uint8")
    kernel[:, 1] = 1
    kernel[1, :] = 1
    tmpim = cv2.dilate(im, kernel)
    tmpim[mask] = im[mask]
    return tmpim

def show(im):
    plt.figure()
    plt.imshow(im, interpolation = "nearest")

m = bim > 0
xim[~m] = -1
yim[~m] = -1
#xim = dilate_mask(xim, m)
#yim = dilate_mask(yim, m)
#bim = dilate_mask(bim, m)

nmap = np.zeros(sh.shape, dtype = "uint8")

nmap[:, :, 2] = (0.5 * xim[1:-1, 1:-1] + 0.5) * 255
nmap[:, :, 1] = (0.5 * yim[1:-1, 1:-1] + 0.5) * 255
nmap[:, :, 3] = bim[1:-1, 1:-1] * 255
nmap[:, :, 0] = (l[1:-1, 1:-1] == 0) * 255


#show(cv2.dilate(nmap[:, :, 2], np.ones((3, 3), dtype = 'uint8')))
#plt.show()

cv2.imwrite(out, nmap)
