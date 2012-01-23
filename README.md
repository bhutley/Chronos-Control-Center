# Chronos Control Center #

This is the TCL source code from Texas Instruments for the Chronos Control Center used to interface with the TI Chronos EZ430 Watch.

This code was originally posted in [Google Groups](http://groups.google.com/group/ti-chronos-development-/browse_thread/thread/3551aae839458b66) by Ojas Parekh. It is based on the code that gets distributed with the watch, but has been modified to use the first Mac OS/X serial port.

If the software can't detect the USB dongle, try changing the line

``set com "/dev/cu.usbmodem001"``

