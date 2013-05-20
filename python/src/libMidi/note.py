from PyQt4 import QtGui

class Note :
    numbers = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A", "B"]
    noteToPisteNumber = {"C3":1, "D3":2, "F3":3, "G3":4, "C4":5, "D4":6, "E4":7, "F4":8, "F#4":9, "G4":10, "A5":11, "A#4":12, "B4":13, "C5":14, "C#5":15, "D5":16, "D#5":17, "E5":18, "F5":19, "F#5":20, "G5":21, "G#5":22, "A5":23, "A#5":24, "B5":25, "C6":26, "D6":27}

    def __init__(self, byte=None, number=None, octave=None, timeIn=0, timeOut=0, velocity=0,) :
        self.numer=number
        self.octave=octave
        self.timeIn=timeIn
        self.timeOut=timeOut
        self.velocity=velocity
        self.color = QtGui.QColor(0,255,0)

        if not byte is None : self.setByte(byte)

    # Permet de configurer la note selon un byte comme specifie dans la
    # norme Midi
    def setByte(self, byte) :
        self.number=Note.numbers[byte%12]
        self.octave=byte//12
        self.byte = byte


    # Cast as String
    def __str__(self) :
        try :
            return self.number + str(self.octave)
        except :
            return "#INCONNU"

    def setTimeOut(self, timeOut):
        self.timeOut=timeOut

    def setColor(self, r, g, b) :
        self.color = QtGui.QColor(r, g, b)

if __name__ == "__main__" :
    n = Note()
    n.setByte(127)
    print (n.number, n.octave)
