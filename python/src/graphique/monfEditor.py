#-------------------------------------------------------------------------------
# Name:        monfEditor.py
# Purpose:
#
# Author:      Thibaut
#
# Created:     14/03/2013
# Copyright:   (c) Thibaut 2013
# Licence:     WTF
#-------------------------------------------------------------------------------

from PyQt4 import QtGui, QtCore

class MonfEditor(QtGui.QWidget) :
    def __init__(self, parent=None, monf=None) :
        self._monf = monf
        self._parent = parent
        QtGui.QWidget.__init__(self, self._parent)

        self.sizeX, self.sizeY = 600, 700

        # Couleurs de base
        self.couleurFond    = QtGui.QColor(230,230,230)
        self.couleurPortee  = QtGui.QColor(200,200,200)
        self.couleurPiste   = QtGui.QColor(200,10,30)

        # Longueurs/Hauteurs constantes
        self.hauteurPiste = 24
        self.sizeY = 27*self.hauteurPiste # 27 = nombre de pistes

        self._DST = 50 #Distance, en pixels, correspondant a 1s de musique

        if not monf is None : self.taillePoincon = monf._morceau._taillePoincon / monf._morceau._DST

        self.getPoincons()

        self.show()

    def getPoincons(self) :
        self.poincons = self._monf.getAllPoincons()
        print (self._monf.getNombrePoincons(self.poincons))

    def paintEvent(self, e) :
        self.resize(self.sizeX, self.sizeY)

        qp = QtGui.QPainter()
        qp.begin(self)

        # Rectangle blanchatre de fond
        qp.fillRect(0,0, self.sizeX, self.sizeY, QtGui.QBrush(self.couleurFond))
        # Ajout des portees
        for i in range(27) :
            qp.fillRect(0,(i+.5)*self.hauteurPiste, self.sizeX, 2, QtGui.QBrush(self.couleurPortee))

        # Si on n'a pas de monf, on s'arrete ici
        if self._monf is None :
            return
        # Sinon, on continue
        # On affiche les notes
        time0, time1 = 0, 1000 # ***** FIXME ******
        notes = self._monf._morceau.getNotesBetween(time0, time1)
        for note in notes :
                    qp.fillRect(self._DST*note.timeIn, self._monf.getNumeroPisteOfNote(note)*self.hauteurPiste + 2 , max(1, self._DST*(note.timeOut - note.timeIn)), self.hauteurPiste - 4, self.couleurPiste)


class ConteneurMonf(MonfEditor, QtGui.QFrame) :
    def __init__(self, parent=None, monf=None) :
        MonfEditor.__init__(self, self, monf)
        QtGui.QFrame.__init__(self, parent)

    def initialize(self) :
        pass


if __name__ == '__main__':
    import sys

    sys.path.append("../libMidi")
    sys.path.append("../libMidi/midi")

    import morceau
    import monf
    m = morceau.Morceau("../../../multimedia/MIDIFILES/TEST1.mid")
    monfFile = m.parseOutput()



    app = QtGui.QApplication(sys.argv)
    app.setApplicationName('monfEditor')
    win = MonfEditor(monf=monfFile)
    win.resize(200, 100)
    win.show()
    sys.exit(app.exec_())
