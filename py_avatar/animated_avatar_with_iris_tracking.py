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
avatar_left_iris = cv2.imread('avatar_left_iris.png', cv2.IMREAD_UNCHANGED)
avatar_right_iris = cv2.imread('avatar_right_iris.png', cv2.IMREAD_UNCHANGED)

# Predefine the points of the avatar to bind to the facial landmarks
# Example: [left_corner, right_corner, top_center, bottom_center]
avatar_mouth_points = np.float32([
    [0, avatar_mouth.shape[0] // 2],  # left corner
    [avatar_mouth.shape[1], avatar_mouth.shape[0] // 2],  # right corner
    [avatar_mouth.shape[1] // 2, 0],  # top center
    [avatar_mouth.shape[1] // 2, avatar_mouth.shape[0]]  # bottom center
])

avatar_left_eye_points = np.float32([
    [0, avatar_left_eye.shape[0] // 2],  # left corner
    [avatar_left_eye.shape[1], avatar_left_eye.shape[0] // 2],  # right corner
    [avatar_left_eye.shape[1] // 2, 0],  # top center
    [avatar_left_eye.shape[1] // 2, avatar_left_eye.shape[0]]  # bottom center
])

avatar_right_eye_points = np.float32([
    [0, avatar_right_eye.shape[0] // 2],  # left corner
    [avatar_right_eye.shape[1], avatar_right_eye.shape[0] // 2],  # right corner
    [avatar_right_eye.shape[1] // 2, 0],  # top center
    [avatar_right_eye.shape[1] // 2, avatar_right_eye.shape[0]]  # bottom center
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

def find_iris_center(eye_image):
    """ Find the center of the iris using image processing techniques. """
    gray_eye = cv2.cvtColor(eye_image, cv2.COLOR_BGR2GRAY)
    gray_eye = cv2.GaussianBlur(gray_eye, (7, 7), 0)
    circles = cv2.HoughCircles(gray_eye, cv2.HOUGH_GRADIENT, 1, 20, param1=50, param2=30, minRadius=5, maxRadius=30)

    if circles is not None:
        circles = np.round(circles[0, :]).astype("int")
        for (x, y, r) in circles:
            return (x, y)
    return None

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

        # Extract specific landmarks for the left eye
        left_eye_points = np.float32([[shape.part(36).x, shape.part(36).y],  # left corner
                                      [shape.part(39).x, shape.part(39).y],  # right corner
                                      [shape.part(37).x, shape.part(37).y],  # top left
                                      [shape.part(41).x, shape.part(41).y]])  # bottom left

        # Apply affine transformation to align avatar left eye with detected left eye points
        left_eye_transform = cv2.getAffineTransform(avatar_left_eye_points[:3], left_eye_points[:3])
        transformed_left_eye = cv2.warpAffine(avatar_left_eye, left_eye_transform, (frame.shape[1], frame.shape[0]), None, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT_101)

        # Create a mask for the transformed left eye
        left_eye_mask = cv2.cvtColor(transformed_left_eye, cv2.COLOR_BGRA2GRAY)
        _, left_eye_mask = cv2.threshold(left_eye_mask, 1, 255, cv2.THRESH_BINARY)

        # Invert the mask
        left_eye_mask_inv = cv2.bitwise_not(left_eye_mask)

        # Black-out the area of the left eye in the region of interest (ROI) in the landmark image
        landmark_image_bg = cv2.bitwise_and(landmark_image, landmark_image, mask=left_eye_mask_inv)

        # Take only the region of the transformed left eye
        transformed_left_eye_fg = cv2.bitwise_and(transformed_left_eye, transformed_left_eye, mask=left_eye_mask)

        # Put the left eye in the ROI and modify the landmark image
        landmark_image = cv2.add(landmark_image_bg, transformed_left_eye_fg)

        # Extract specific landmarks for the right eye
        right_eye_points = np.float32([[shape.part(42).x, shape.part(42).y],  # left corner
                                       [shape.part(45).x, shape.part(45).y],  # right corner
                                       [shape.part(43).x, shape.part(43).y],  # top right
                                       [shape.part(47).x, shape.part(47).y]])  # bottom right

        # Apply affine transformation to align avatar right eye with detected right eye points
        right_eye_transform = cv2.getAffineTransform(avatar_right_eye_points[:3], right_eye_points[:3])
        transformed_right_eye = cv2.warpAffine(avatar_right_eye, right_eye_transform, (frame.shape[1], frame.shape[0]), None, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT_101)

        # Create a mask for the transformed right eye
        right_eye_mask = cv2.cvtColor(transformed_right_eye, cv2.COLOR_BGRA2GRAY)
        _, right_eye_mask = cv2.threshold(right_eye_mask, 1, 255, cv2.THRESH_BINARY)

        # Invert the mask
        right_eye_mask_inv = cv2.bitwise_not(right_eye_mask)

        # Black-out the area of the right eye in the region of interest (ROI) in the landmark image
        landmark_image_bg = cv2.bitwise_and(landmark_image, landmark_image, mask=right_eye_mask_inv)

        # Take only the region of the transformed right eye
        transformed_right_eye_fg = cv2.bitwise_and(transformed_right_eye, transformed_right_eye, mask=right_eye_mask)

        # Put the right eye in the ROI and modify the landmark image
        landmark_image = cv2.add(landmark_image_bg, transformed_right_eye_fg)

        # Extract the eye regions for iris detection
        left_eye_region = frame[shape.part(37).y:shape.part(41).y, shape.part(36).x:shape.part(39).x]
        right_eye_region = frame[shape.part(43).y:shape.part(47).y, shape.part(42).x:shape.part(45).x]

        # Find the iris centers
        left_iris_center = find_iris_center(left_eye_region)
        right_iris_center = find_iris_center(right_eye_region)

        if left_iris_center:
            # Apply affine transformation to align avatar left iris with detected left iris center
            left_iris_transform = cv2.getAffineTransform(np.float32([[0, 0], [avatar_left_iris.shape[1], 0], [0, avatar_left_iris.shape[0]]]), np.float32([[left_iris_center[0] - 5, left_iris_center[1] - 5], [left_iris_center[0] + 5, left_iris_center[1] - 5], [left_iris_center[0] - 5, left_iris_center[1] + 5]]))
            transformed_left_iris = cv2.warpAffine(avatar_left_iris, left_iris_transform, (frame.shape[1], frame.shape[0]), None, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT_101)

            # Create a mask for the transformed left iris
            left_iris_mask = cv2.cvtColor(transformed_left_iris, cv2.COLOR_BGRA2GRAY)
            _, left_iris_mask = cv2.threshold(left_iris_mask, 1, 255, cv2.THRESH_BINARY)

            # Invert the mask
            left_iris_mask_inv = cv2.bitwise_not(left_iris_mask)

            # Black-out the area of the left iris in the region of interest (ROI) in the landmark image
            landmark_image_bg = cv2.bitwise_and(landmark_image, landmark_image, mask=left_iris_mask_inv)

            # Take only the region of the transformed left iris
            transformed_left_iris_fg = cv2.bitwise_and(transformed_left_iris, transformed_left_iris, mask=left_iris_mask)

            # Put the left iris in the ROI and modify the landmark image
            landmark_image = cv2.add(landmark_image_bg, transformed_left_iris_fg)

        if right_iris_center:
            # Apply affine transformation to align avatar right iris with detected right iris center
            right_iris_transform = cv2.getAffineTransform(np.float32([[0, 0], [avatar_right_iris.shape[1], 0], [0, avatar_right_iris.shape[0]]]), np.float32([[right_iris_center[0] - 5, right_iris_center[1] - 5], [right_iris_center[0] + 5, right_iris_center[1] - 5], [right_iris_center[0] - 5, right_iris_center[1] + 5]]))
            transformed_right_iris = cv2.warpAffine(avatar_right_iris, right_iris_transform, (frame.shape[1], frame.shape[0]), None, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT_101)

            # Create a mask for the transformed right iris
            right_iris_mask = cv2.cvtColor(transformed_right_iris, cv2.COLOR_BGRA2GRAY)
            _, right_iris_mask = cv2.threshold(right_iris_mask, 1, 255, cv2.THRESH_BINARY)

            # Invert the mask
            right_iris_mask_inv = cv2.bitwise_not(right_iris_mask)

            # Black-out the area of the right iris in the region of interest (ROI) in the landmark image
            landmark_image_bg = cv2.bitwise_and(landmark_image, landmark_image, mask=right_iris_mask_inv)

            # Take only the region of the transformed right iris
            transformed_right_iris_fg = cv2.bitwise_and(transformed_right_iris, transformed_right_iris, mask=right_iris_mask)

            # Put the right iris in the ROI and modify the landmark image
            landmark_image = cv2.add(landmark_image_bg, transformed_right_iris_fg)

    # Display the resulting image with landmarks and morphed avatar
    cv2.imshow('Facial Landmarks with Morphed Avatar', landmark_image)

    # Hit 'q' on the keyboard to quit!
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

# Release handle to the webcam
video_capture.release()
cv2.destroyAllWindows()