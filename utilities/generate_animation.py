import cv2
import numpy as np
import matplotlib.pyplot as plt
import argparse
import sys
import math
import string
import os

parser = argparse.ArgumentParser(description='Crops frames and extracts hitbox info')
parser.add_argument(
    "-f", "--frame", dest = "frame", help = "Output path for frame"
)
parser.add_argument(
    "-l", "--lua", dest = "lua", help = "Output path for info file"
)
parser.add_argument(
    "-w", "--width", dest = "width", help = "Width of animation frame"
)
parser.add_argument(
    "-e", "--height", dest = "height", help = "height of animation frame"
)
parser.add_argument(
    "path", metavar = "N", type = str, nargs='+',
    help = "Path to animation frame and hitbox files"
)
args = parser.parse_args()

if args.lua is None:
    print "Please provide lua file path"
    sys.exit(-1)
if args.frame is None:
    print "Please provide frame file path"
    sys.exit(-2)
if args.width is None:
    print "Please provide frame width"
    sys.exit(-3)
if args.height is None:
    print "Please provide frame height"
    sys.exit(-4)

frame_shape = (int(args.height), int(args.width))

if len(args.path) < 1:
    print "Please provide animation frame and hitbox in that order"
    sys.exit(-5)
animation_im = cv2.imread(args.path[0], -1)
# Encode hitbox color as hexadecimal numbers
hitbox_im = np.zeros(animation_im.shape, dtype = "uint32")
if len(args.path) > 1:
    hitbox_im = cv2.imread(args.path[1], 1).astype("uint32")
hitbox_im_hash = hitbox_im[:, :, 0] + np.left_shift(hitbox_im[:, :, 1], 8) \
                + np.left_shift(hitbox_im[:, :, 2], 16)

# Registser which color coded hitboxes are present
colorhash_vec = hitbox_im_hash.reshape(-1)
d = dict(zip(colorhash_vec, colorhash_vec))
del d[0]
colorhashes = d.keys()

# Function for retriving a frame area given an images
frames = animation_im.shape[1] / frame_shape[1]
def get_frame(im, frame):
    cl = frame * frame_shape[1]
    cu = cl + frame_shape[1]
    if len(im.shape) > 2:
        return im[:, cl:cu, :]
    else:
        return im[:, cl:cu]

def get_frame_seq(im, count):
    return map(lambda i: get_frame(im, i), np.arange(count))

hitbox_im_binary = map(lambda h: hitbox_im_hash == h, colorhashes)
animation_im_binary = animation_im[:, :, 3] > 10

def plot_shared(im_array, title = ""):
    rows = 3
    cols = int(math.ceil(len(im_array) / float(rows)))
    f, axarr = plt.subplots(rows, cols, sharex = True, sharey = True)

    def access(r, c):
        if cols != 1:
            return axarr[r, c]
        else:
            return axarr[r]

    for i, im in enumerate(im_array):
        r = i % rows
        c = i / rows
        access(r, c).imshow(im, interpolation = "nearest")
    access(0, 0).set_title(title)


def _get_AABB(cont):
    x = cont[:, 0, 0]
    y = cont[:, 0, 1]
    return (np.min(x), np.min(y), np.max(x), np.max(y))


def find_hitboxes(frame):
    w, h = frame.shape[1], frame.shape[0]
    frame_border = np.zeros((h + 2, w + 2), dtype = "uint8")
    frame_border[1:-1, 1:-1] = frame
    cont, _ = cv2.findContours(
        frame_border, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE
    )
    for c in cont:
        c -= 1
    box = map(_get_AABB, cont)
    return box

hitbox_seq_binary = map(lambda im: get_frame_seq(im, frames), hitbox_im_binary)
hitbox_seq_border = map(lambda seq: map(find_hitboxes, seq), hitbox_seq_binary)

animation_seq_binary = get_frame_seq(animation_im_binary, frames)
animation_seq_border = map(find_hitboxes, animation_seq_binary)

def total_frame_border(borders):
    if len(borders) == 0:
        return ()
    xmin = np.inf
    xmax = -np.inf
    ymin = np.inf
    ymax = -np.inf
    for _xmin, _ymin, _xmax, _ymax in borders:
        xmin = min(xmin, _xmin)
        xmax = max(xmax, _xmax)
        ymin = min(ymin, _ymin)
        ymax = max(ymax, _ymax)

    return (xmin, ymin, xmax, ymax)

animation_seq_border = map(total_frame_border, animation_seq_border)

hitbox_border_dic = dict(zip(colorhashes, hitbox_seq_border))
for key in hitbox_border_dic.keys():
    hitbox_border_dic[key] = map(total_frame_border, hitbox_border_dic[key])
# Let us take the default
entity_seq = [(0, 0, frame_shape[1], frame_shape[0])] * frames
if hitbox_border_dic.has_key(0xff00):
    entity_seq = hitbox_border_dic[0xff00]

def center_of_mass((minx, miny, maxx, maxy)):
    return (minx + maxx) * 0.5, (miny + maxy) * 0.5

def shape((minx, miny, maxx, maxy)):
    return (maxx - minx) * 0.5, (maxy - miny) * 0.5

center_seq = map(center_of_mass, entity_seq)
shape_seq = map(shape, entity_seq)

def motion((center1, center2)):
    (x1, _) = center1
    (x2, _) = center2
    return x2 - x1

vx_seq = map(motion, zip(center_seq[:-1], center_seq[1:]))

# Transform all coordinates to being relative to the center of mass
def frame_offset((frame_border, center)):
    (cx, cy) = center
    (minx, miny, maxx, maxy) = frame_border
    return (cx - minx, cy - miny)

offset_seq = map(frame_offset, zip(animation_seq_border, center_seq))

final_frame_shape = [0, 0, 4]
for (minx, miny, maxx, maxy) in animation_seq_border:
    final_frame_shape[0] = max(final_frame_shape[0], maxy - miny + 1)
    final_frame_shape[1] += maxx - minx + 1

final_frame = np.zeros(final_frame_shape, dtype = "uint8")

x = 0
for f, (minx, miny, maxx, maxy) in enumerate(animation_seq_border):
    pre = get_frame(animation_im, f)
    pre_sub = pre[miny:maxy + 1, minx:maxx + 1]
    final_frame[:pre_sub.shape[0], x:x + pre_sub.shape[1], :] = pre_sub
    x += pre_sub.shape[1]

def get_width((minx, miny, maxx, maxy)):
    return maxx - minx + 1

frame_size_seq = map(get_width, animation_seq_border)

def format2lua(s):
    s = string.replace(s, "(", "{")
    s = string.replace(s, ")", "}")
    s = string.replace(s, "[", "{")
    s = string.replace(s, "]", "}")
    return s

def hitbox_offset(hitbox, center):
    if len(hitbox) == 0:
        return ()
    (cx, cy) = center
    (minx, miny, maxx, maxy) = hitbox
    return minx - cx, cy - maxy, maxx - minx, maxy - miny

hitbox_str = ""
for key in hitbox_border_dic.keys():
    seq = hitbox_border_dic[key]
    cor_seq = map(
        lambda (h, center): hitbox_offset(h, center), zip(seq, center_seq)
    )
    key_str = "0x{:06x}".format(key)
    lua_seq = format2lua(str(cor_seq))
    hitbox_str += "\t\t\t[{0}] = {1},\n".format(key_str, lua_seq)

offset_x_seq = map(lambda s: s[0], offset_seq)
offset_y_seq = map(lambda s: s[1] + 1, offset_seq)

width_seq = map(lambda s: s[0], shape_seq)
height_seq = map(lambda s: s[1], shape_seq)

tab_name = os.path.splitext(os.path.basename(args.path[0]))[0]
output_str = "\t{0} = {{\n".format(tab_name)
output_str += "\t\toffset_x = {0},\n".format(format2lua(str(offset_x_seq)))
output_str += "\t\toffset_y = {0},\n".format(format2lua(str(offset_y_seq)))
output_str += "\t\tvx = {0},\n".format(format2lua(str(vx_seq)))
output_str += "\t\tframe_size = {0},\n".format(format2lua(str(frame_size_seq)))
output_str += "\t\twidth = {0},\n".format(format2lua(str(width_seq)))
output_str += "\t\theight = {0},\n".format(format2lua(str(height_seq)))
output_str += "\t\thitbox = {{\n{0}\n\t\t}}\n".format(hitbox_str)
output_str += "\t},\n"

cv2.imwrite(args.frame, final_frame)

f = open(args.lua, "w")
f.write(''.join(output_str))
f.close()
