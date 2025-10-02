import cv2
import mediapipe as mp
import numpy as np
import pygame as pg
import threading
import time

CAM_WIDTH = 320
CAM_HEIGHT = 240
PG_SCREEN_SCALE = 2
PG_SCREEN_WIDTH = CAM_WIDTH * PG_SCREEN_SCALE
PG_SCREEN_HEIGHT = CAM_HEIGHT * PG_SCREEN_SCALE

face_mesh_finder = mp.solutions.face_mesh.FaceMesh(max_num_faces=1, refine_landmarks=True)
cam_stream = cv2.VideoCapture(0)
cam_stream.set(cv2.CAP_PROP_FRAME_WIDTH, CAM_WIDTH)
cam_stream.set(cv2.CAP_PROP_FRAME_HEIGHT, CAM_HEIGHT)

pg.init()
screen = pg.display.set_mode((PG_SCREEN_WIDTH, PG_SCREEN_HEIGHT))
clock = pg.time.Clock()

landmarks = {
        'upper_lip_bottom': [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308],
        'lower_lip_top': [78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308],
        'left_eye_top': [362, 398, 384, 385, 386, 387, 388, 466, 263],
        'left_eye_bottom': [362, 382, 381, 380, 374, 373, 390, 249, 263],
        'right_eye_top': [133, 173, 157, 158, 159, 160, 161, 246, 33],
        'right_eye_bottom': [133, 155, 154, 153, 145, 144, 163, 7, 33],
        'left_brow_top': [336, 296, 334, 293, 300],
        'right_brow_top': [107, 66, 105, 63, 70],
        'left_iris': [473],
        'right_iris': [468]
        }

#data = {
#    'upper_lip_bottom': [(0, 0)] * len(landmarks['upper_lip_bottom']),
#    'lower_lip_top': [(0, 0)] * len(landmarks['lower_lip_top'])
#        }

data = { k: [(0, 0)] * len(v) for k, v in landmarks.items() }

def track_face():
    while True:
        ret, frame = cam_stream.read()
        if not ret:
            break
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh_finder.process(frame_rgb)
        if results.multi_face_landmarks:
            for face_landmarks in results.multi_face_landmarks:
                for k, v in landmarks.items():
                    data[k] = [(face_landmarks.landmark[i].x * CAM_WIDTH * PG_SCREEN_SCALE, face_landmarks.landmark[i].y * CAM_HEIGHT * PG_SCREEN_SCALE) for i in v]


old_data = dict(data)
def draw_avatar(screen, data):
    # pre-smoothing
    global old_data
    alpha = 0.8
    new_data = { k: [(x[0] * alpha + old_data[k][i][0] * (1-alpha), x[1] * alpha + old_data[k][i][1] * (1-alpha)) for i, x in enumerate(v)] for k, v in data.items() }
    old_data = dict(new_data)

    # start drawing
    screen.fill((0, 255, 0))
    pg.draw.lines(screen, (0, 0, 0), False, new_data['upper_lip_bottom'], 2)
    pg.draw.lines(screen, (0, 0, 0), False, new_data['lower_lip_top'], 2)
    pg.draw.lines(screen, (0, 0, 0), False, new_data['left_eye_top'], 2)
    pg.draw.lines(screen, (0, 0, 0), False, new_data['left_eye_bottom'], 2)
    pg.draw.lines(screen, (0, 0, 0), False, new_data['right_eye_top'], 2)
    pg.draw.lines(screen, (0, 0, 0), False, new_data['right_eye_bottom'], 2)
    pg.draw.lines(screen, (0, 0, 0), False, new_data['left_brow_top'], 2)
    pg.draw.lines(screen, (0, 0, 0), False, new_data['right_brow_top'], 2)
    pg.draw.circle(screen, (255, 255, 255), new_data['left_iris'][0], 5)
    pg.draw.circle(screen, (255, 255, 255), new_data['right_iris'][0], 5)


threading.Thread(target=track_face, daemon=True).start()
running = True
while running:
    for event in pg.event.get():
        if event.type == pg.QUIT:
            running = False
    draw_avatar(screen, data)
    pg.display.flip()
    clock.tick(20)

pg.quit()
cam_stream.release()
face_mesh_finder.close()
