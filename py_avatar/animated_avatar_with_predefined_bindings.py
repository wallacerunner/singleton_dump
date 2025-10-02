import face_recognition
import cv2
import dlib
import numpy as np

# Load a sample picture and learn how to recognize it.
image_of_person = face_recognition.load_image_file("person.jpg")
person_face_encoding = face_recognition.face_encodings(image_of_person)[0]

# Create arrays of known face encodings and their names
known_face_encodings = [
    person_face_encoding
]
known_face_names = [
    "Person Name"
]

# Initialize some variables
face_locations = []
face_encodings = []
face_names = []

# Load the pre-trained dlib shape predictor model
predictor_path = "shape_predictor_68_face_landmarks.dat"
detector = dlib.get_frontal_face_detector()
predictor = dlib.shape_predictor(predictor_path)

# Load the avatar image and its parts
avatar = cv2.imread('avatar.png', cv2.IMREAD_UNCHANGED)
avatar_mouth = cv2.imread('avatar_mouth.png', cv2.IMREAD_UNCHANGED)
avatar_left_eye = cv2.imread('avatar_left_eye.png', cv2.IMREAD_UNCHANGED)
avatar_right_eye = cv2.imread('avatar_right_eye.png', cv2.IMREAD_UNCHANGED)

# Predefine the points of the avatar to bind to the facial landmarks
# Example: [mouth_left, mouth_right, mouth_top, mouth_bottom]
avatar_mouth_points = np.float32([
    [0, avatar_mouth.shape[0] // 2],  # left corner
    [avatar_mouth.shape[1], avatar_mouth.shape[0] // 2],  # right corner
    [avatar_mouth.shape[1] // 2, 0],  # top center
    [avatar_mouth.shape[1] // 2, avatar_mouth.shape[0]]  # bottom center
])

# Open a video stream
video_capture = cv2.VideoCapture(0)

def apply_affine_transform(src, src_tri, dst_tri, size):
    """ Apply affine transform calculated using src_tri and dst_tri to src and output an image of size. """
    warp_mat = cv2.getAffineTransform(np.float32(src_tri), np.float32(dst_tri))
    dst = cv2.warpAffine(src, warp_mat, (size[0], size[1]), None, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT_101)
    return dst

def warp_triangle(img1, img2, t1, t2):
    """ Warps and alpha blends triangular regions from img1 and img2 to img2. """
    # Find bounding rectangle for each triangle
    r1 = cv2.boundingRect(np.float32([t1]))
    r2 = cv2.boundingRect(np.float32([t2]))

    # Offset points by left top corner of the respective rectangles
    t1_rect = []
    t2_rect = []
    t2_rect_int = []

    for i in range(3):
        t1_rect.append(((t1[i][0] - r1[0]), (t1[i][1] - r1[1])))
        t2_rect.append(((t2[i][0] - r2[0]), (t2[i][1] - r2[1])))
        t2_rect_int.append(((t2[i][0] - r2[0]), (t2[i][1] - r2[1])))

    # Get mask by filling triangle
    mask = np.zeros((r2[3], r2[2], 3), dtype = np.float32)
    cv2.fillConvexPoly(mask, np.int32(t2_rect_int), (1.0, 1.0, 1.0), 16, 0)

    # Apply warpImage to small rectangular patches
    img1_rect = img1[r1[1]:r1[1] + r1[3], r1[0]:r1[0] + r1[2]]
    size = (r2[2], r2[3])
    img2_rect = apply_affine_transform(img1_rect, t1_rect, t2_rect, size)

    img2_rect = img2_rect * mask

    # Copy triangular region of the rectangular patch to the output image
    img2[r2[1]:r2[1] + r2[3], r2[0]:r2[0] + r2[2]] = img2[r2[1]:r2[1] + r2[3], r2[0]:r2[0] + r2[2]] * ((1.0, 1.0, 1.0) - mask)
    img2[r2[1]:r2[1] + r2[3], r2[0]:r2[0] + r2[2]] = img2[r2[1]:r2[1] + r2[3], r2[0]:r2[0] + r2[2]] + img2_rect

while True:
    # Grab a single frame of video
    ret, frame = video_capture.read()

    # Resize frame of video to 1/4 size for faster face recognition processing
    small_frame = cv2.resize(frame, (0, 0), fx=0.25, fy=0.25)

    # Convert the image from BGR color (which OpenCV uses) to RGB color (which face_recognition uses)
    rgb_small_frame = small_frame[:, :, ::-1]

    # Find all the faces and face encodings in the current frame of video
    face_locations = face_recognition.face_locations(rgb_small_frame)
    face_encodings = face_recognition.face_encodings(rgb_small_frame, face_locations)

    face_names = []
    for face_encoding in face_encodings:
        # See if the face is a match for the known face(s)
        matches = face_recognition.compare_faces(known_face_encodings, face_encoding)
        name = "Unknown"

        # If a match was found in known_face_encodings, use the first one.
        if True in matches:
            first_match_index = matches.index(True)
            name = known_face_names[first_match_index]

        face_names.append(name)

    # Create a blank image for drawing facial landmarks
    landmark_image = np.zeros_like(frame, dtype=np.uint8)

    # Convert the image to grayscale
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # Detect faces in the grayscale image
    rects = detector(gray, 0)

    # Loop over the face detections
    for rect in rects:
        # Get the facial landmarks
        shape = predictor(gray, rect)

        # Extract specific landmarks for the mouth
        mouth_points = np.float32([[shape.part(48).x, shape.part(48).y],  # left corner
                                   [shape.part(54).x, shape.part(54).y],  # right corner
                                   [shape.part(51).x, shape.part(51).y],  # top center
                                   [shape.part(57).x, shape.part(57).y]])  # bottom center

        # Apply affine transformation to align avatar mouth with detected mouth points
        mouth_transform = cv2.getAffineTransform(avatar_mouth_points[:3], mouth_points[:3])
        transformed_mouth = cv2.warpAffine(avatar_mouth, mouth_transform, (frame.shape[1], frame.shape[0]), None, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT_101)

        # Create a mask for the transformed mouth
        mouth_mask = cv2.cvtColor(transformed_mouth, cv2.COLOR_BGRA2GRAY)
        _, mouth_mask = cv2.threshold(mouth_mask, 1, 255, cv2.THRESH_BINARY)

        # Invert the mask
        mouth_mask_inv = cv2.bitwise_not(mouth_mask)

        # Black-out the area of the mouth in the region of interest (ROI) in the landmark image
        landmark_image_bg = cv2.bitwise_and(landmark_image, landmark_image, mask=mouth_mask_inv)

        # Take only the region of the transformed mouth
        transformed_mouth_fg = cv2.bitwise_and(transformed_mouth, transformed_mouth, mask=mouth_mask)

        # Put the mouth in the ROI and modify the landmark image
        landmark_image = cv2.add(landmark_image_bg, transformed_mouth_fg)

    # Display the resulting image with landmarks and morphed avatar
    cv2.imshow('Facial Landmarks with Morphed Avatar', landmark_image)

    # Hit 'q' on the keyboard to quit!
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

# Release handle to the webcam
video_capture.release()
cv2.destroyAllWindows()