import cv2
import mediapipe as mp
import numpy as np
import pygame
import threading
import time

# MediaPipe
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(max_num_faces=1, refine_landmarks=True)
cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 320)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 240)

# Pygame
pygame.init()
screen = pygame.display.set_mode((400, 300))
clock = pygame.time.Clock()

# Smoothing
class Smoother:
    def __init__(self, alpha=0.3):
        self.alpha = alpha
        self.value = None
    def update(self, new_value):
        if self.value is None:
            self.value = new_value
        else:
            self.value = self.alpha * new_value + (1 - self.alpha) * self.value
        return self.value

smoothers = {
    "left_x": Smoother(), "left_y": Smoother(),
    "right_x": Smoother(), "right_y": Smoother(),
    "yaw": Smoother(), "mouth_open": Smoother(), "mouth_curve": Smoother()
}

# Shared data
data = {
        "left_pupil": [0, 0], 
        "right_pupil": [0, 0], 
        "yaw": 0,
        "center": [0, 0],
        "mouth_open": 0,
        "blink": False,
        "mouth_curve": 0,
        'upper_lip': [[0.0, 0.0]] * 5,
        'lower_lip': [[0.0, 0.0]] * 5
        }
blink_state = {"active": False, "start_time": 0, "duration": 0.2}

def track_face():
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(frame_rgb)
        h, w, _ = frame.shape
        if results.multi_face_landmarks:
            for face_landmarks in results.multi_face_landmarks:
                data["left_pupil"] = [face_landmarks.landmark[468].x * w, face_landmarks.landmark[468].y * h]
                data["right_pupil"] = [face_landmarks.landmark[473].x * w, face_landmarks.landmark[473].y * h]
                nose = face_landmarks.landmark[1]
                left_ear = face_landmarks.landmark[234]
                right_ear = face_landmarks.landmark[454]
                data["yaw"] = smoothers["yaw"].update(np.arctan2(right_ear.x - left_ear.x, right_ear.y - left_ear.y))
                #upper_lip = face_landmarks.landmark[13]
                #lower_lip = face_landmarks.landmark[14]
                #data["mouth_open"] = smoothers["mouth_open"].update((lower_lip.y - upper_lip.y) * h)
                #left_corner = face_landmarks.landmark[61]
                #right_corner = face_landmarks.landmark[291]
                #data["mouth_curve"] = smoothers["mouth_curve"].update((right_corner.y - left_corner.y) * h)
                left_ear = eye_aspect_ratio([362, 385, 387, 263, 373, 380], face_landmarks.landmark, w, h)
                if left_ear < 0.2 and not blink_state["active"]:
                    blink_state["active"] = True
                    blink_state["start_time"] = time.time()
                elif blink_state["active"] and time.time() - blink_state["start_time"] > blink_state["duration"]:
                    blink_state["active"] = False
                data["blink"] = blink_state["active"]
                # Upper lip points (example: 13 to 17)
                upper_lip = [(face_landmarks.landmark[i].x * w, face_landmarks.landmark[i].y * h)
                             for i in [13, 14, 15, 16, 17]]
                # Lower lip points (example: 14 to 18, adjust as needed)
                lower_lip = [(face_landmarks.landmark[i].x * w, face_landmarks.landmark[i].y * h)
                             for i in [14, 18, 19, 20, 21]]  # Adjust indices based on testing
                data["upper_lip"] = [smoothers.get(f"upper_{i}", Smoother()).update(p) for i, p in enumerate(upper_lip)]
                data["lower_lip"] = [smoothers.get(f"lower_{i}", Smoother()).update(p) for i, p in enumerate(lower_lip)]

def clamp(value, min_val, max_val):
    return max(min_val, min(max_val, value))

def draw_eye(surface, center, pupil_pos, blink):
    if blink:
        pygame.draw.arc(surface, (0, 0, 0), (center[0] - 10, center[1] - 10, 20, 20), np.pi, 2 * np.pi, 2)
    else:
        pygame.draw.circle(surface, (255, 255, 255), center, 10)
        pygame.draw.circle(surface, (0, 0, 0), pupil_pos, 3)
        pygame.draw.arc(surface, (0, 0, 0), (center[0] - 10, center[1] - 12, 20, 20), 0, np.pi, 1)

def draw_mouth(surface, head_x, upper_lip, lower_lip):
    # Scale points to avatar size (e.g., head radius 50, centered at head_x, 180)
    scale_factor = 50 / 320  # Adjust based on webcam resolution
    avatar_upper = [(head_x - 15 + int((p[0] - 160) * scale_factor),
                     180 + int((p[1] - 120) * scale_factor)) for p in upper_lip]
    avatar_lower = [(head_x - 15 + int((p[0] - 160) * scale_factor),
                     180 + int((p[1] - 120) * scale_factor)) for p in lower_lip]
    # Draw lines
    if len(avatar_upper) > 1:
        pygame.draw.lines(surface, (255, 0, 0), False, avatar_upper, 2)
    if len(avatar_lower) > 1:
        pygame.draw.lines(surface, (200, 0, 0), False, avatar_lower, 2)

def draw_avatar(surface, data):
    surface.fill((255, 255, 255))
    head_x = 200 + int(data["yaw"] * 50)
    pygame.draw.circle(surface, (255, 200, 150), (head_x, 150), 50)
    pygame.draw.circle(surface, (0, 0, 0), (head_x, 150), 50, 2)
    eye_left = (head_x - 20, 140)
    eye_right = (head_x + 20, 140)
    pupil_left = (eye_left[0] + clamp(smoothers["left_x"].update(data["left_pupil"][0] / 320 * 10 - 5), -5, 5),
                  eye_left[1] + clamp(smoothers["left_y"].update(data["left_pupil"][1] / 240 * 10 - 5), -5, 5))
    pupil_right = (eye_right[0] + clamp(smoothers["right_x"].update(data["right_pupil"][0] / 320 * 10 - 5), -5, 5),
                   eye_right[1] + clamp(smoothers["right_y"].update(data["right_pupil"][1] / 240 * 10 - 5), -5, 5))
    draw_eye(surface, eye_left, pupil_left, data["blink"])
    draw_eye(surface, eye_right, pupil_right, data["blink"])
    draw_mouth(surface, head_x, data["upper_lip"], data["lower_lip"])

def eye_aspect_ratio(eye_points, landmarks, w, h):
    p = [np.array([landmarks[i].x * w, landmarks[i].y * h]) for i in eye_points]
    return (np.linalg.norm(p[1] - p[5]) + np.linalg.norm(p[2] - p[4])) / (2 * np.linalg.norm(p[0] - p[3]))


threading.Thread(target=track_face, daemon=True).start()
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
    draw_avatar(screen, data)
    pygame.display.flip()
    clock.tick(20)

pygame.quit()
cap.release()
face_mesh.close()
