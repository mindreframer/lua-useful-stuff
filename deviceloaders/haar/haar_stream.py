#!/usr/bin/python

import os, sys, getopt
import cv

from socket import *
cs = socket(AF_INET, SOCK_DGRAM)
cs.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
#cs.setsockopt(SOL_SOCKET, SO_BROADCAST, 1)

udp_ip = '127.0.0.1'
udp_port = 45454
capture_size = [320,200]
haarfile ='haarcascade_frontalface_alt.xml'
showvideo = False

class FaceDetect():
	def __init__(self):
		if showvideo:
			cv.NamedWindow ("CamShiftDemo", 1)
		device = 0
		self.capture = cv.CaptureFromCAM(device)
		cv.SetCaptureProperty(self.capture, cv.CV_CAP_PROP_FRAME_WIDTH, capture_size[0])
		cv.SetCaptureProperty(self.capture, cv.CV_CAP_PROP_FRAME_HEIGHT, capture_size[1])
		
	def detect(self):
		cv.CvtColor(self.frame, self.grayscale, cv.CV_RGB2GRAY)

		#equalize histogram
		cv.EqualizeHist(self.grayscale, self.grayscale)

		# detect objects
		faces = cv.HaarDetectObjects(image=self.grayscale, cascade=self.cascade, storage=self.storage, scale_factor=1.2,\
									 min_neighbors=2, flags=cv.CV_HAAR_DO_CANNY_PRUNING)
		if faces:
			#print 'face detected!'
			for i in faces:
				if i[1] > 10:
					center = ((2*i[0][0]+i[0][2])/2,(2*i[0][1]+i[0][3])/2)
					#print  center, i, i[0][2]*i[0][3], framesize,size
					packet = '%d %d %d %d' % (center[0], center[1], i[0][2], i[0][3])
					cs.sendto(packet, (udp_ip, udp_port))
					if showvideo:
						radius = (i[0][2]+i[0][3])/4
						cv.Circle(self.frame, center, radius, (128, 255, 128), 2, 8, 0)
	
	def run(self):
		# check if capture device is OK
		if not self.capture:
			print "Error opening capture device"
			sys.exit(1)

		self.frame = cv.QueryFrame(self.capture)
		self.image_size = cv.GetSize(self.frame)

		# create grayscale version
		self.grayscale = cv.CreateImage(self.image_size, 8, 1)

		# create storage
		self.storage = cv.CreateMemStorage(128)
		self.cascade = cv.Load(haarfile)

		while 1:
			# do forever
			# capture the current frame
			self.frame = cv.QueryFrame(self.capture)
			if self.frame is None:
				break

			# mirror
			cv.Flip(self.frame, None, 1)

			# face detection
			self.detect()

			# display webcam image
			if showvideo:
				cv.ShowImage('CamShiftDemo', self.frame)
				
			# handle events
			k = cv.WaitKey(10)

if __name__ == "__main__":
	help_string = """python haar_stream.py [PARAMS]
	-o --ip     defaults to '127.0.0.1'
	-p --port   defaults to 45454
	-v --video  open a window with the video preview
	-s --size   defaults to '320x200'
	-f --file   defaults to 'haarcascade_frontalface_alt.xml'"""

	argv = sys.argv[1:]
	try:
		opts, args = getopt.getopt(argv,"hvo:p:s:f:",["help","view","ip=", "port=", "size=", "file="])
	except getopt.GetoptError:
		print help_string
		sys.exit(2)
	for opt, arg in opts:
		if opt in ("-h", "--help"):
			print help_string
			sys.exit()
		elif opt in ("-v", "--video"):
			showvideo = True
		elif opt in ("-f", "--file"):
			haarfile = arg
		elif opt in ("-o", "--ip"):
			udp_ip = arg
		elif opt in ("-p", "--port"):
			udp_port = int(arg)
		elif opt in ("-s", "--size"):
			capture_size = [int(n) for n in arg.split('x', 2 )];

	face_detect = FaceDetect()
	face_detect.run() 
