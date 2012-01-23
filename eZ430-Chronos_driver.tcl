set vcp            0
set vcp_reply	   ""
set vcp_len	   0
set vcp_pending	   0
set vcp_debug	   0
if { $vcp_debug == 1 } { 
  set fh [open "log.txt" w] 
} else {
  set fh 0
}

# Send string through UART  
proc SendCmd { command } {
  global vcp vcp_reply vcp_len vcp_pending vcp_debug fh

  set timeout 0
  while { $vcp_pending == 1 } {
    if { $vcp_debug == 1  } { puts $fh "Waiting for reply. Delaying command $command." }
    after 5
    update
    incr timeout
    if {$timeout > 100} { 
      set vcp_pending 0 
      if { $vcp_debug == 1  } { puts $fh "Terminating delay loop." }
    }
  }
  update
  if { $vcp_debug == 1  } { puts $fh "Sending $command" }
  
  # Send command 
  set vcp_reply ""
  set vcp_pending 1
  set len [string length $command]
  set vcp_len [expr $len / 2]
  for {set i 0} {$i < $len} {incr i} {  
    set hex 0x[string range $command $i [expr $i+1]]
    set letter [format %c $hex]
    puts -nonewline $vcp $letter
    incr i
  }
  puts -nonewline $vcp "\n"
  flush $vcp
}

# Get UART buffer content 
proc GetReply {} {
  global vcp vcp_reply vcp_len vcp_pending vcp_debug fh

  set cap [read $vcp]
  binary scan $cap cu* valueList
  foreach value $valueList {
    append vcp_reply [format "0x%02X " $value]
  }
  if { $vcp_debug == 1  } { puts $fh "Received: $vcp_reply" }
  flush $vcp
  set vcp_pending 0
}

# Open COM port
proc BM_OpenCOM { port baudrate timeout dts rts } {
  global vcp
  catch { open $port w+ } vcp
  if { [string first "couldn't" $vcp] != -1 } {
    set vcp 0
  } else {
    fconfigure $vcp -mode 115200,n,8,1 
    fconfigure $vcp -blocking 0
    fconfigure $vcp -buffering full -encoding binary -translation binary
    fileevent $vcp readable [list GetReply]
  }
}


# Close COM port
proc BM_CloseCOM {} {
  global vcp fh
  close $vcp
  flush $fh
  close $fh
}

# Reset hardware
proc BM_Reset {} {
  SendCmd "FF0103"
  after 15
}

# Set BlueRobin TX ID
proc BM_BR_SetID { id } {
  SendCmd "FF0307[format %02X [expr $id & 0xFF]][format %02X [expr ($id>>8) & 0xFF]][format %02X [expr ($id>>16) & 0xFF]][format %02X [expr ($id>>24) & 0xFF]]"
  after 15
}

# Start BlueRobin TX
proc BM_BR_Start {} {
  SendCmd "FF0203"
  after 15
}

# Stop BlueRobin TX
proc BM_BR_Stop {} {
  SendCmd "FF0603"
  after 15
}


# Set BlueRobin heart rate value
proc BM_BR_SetHeartrate { hr } {
  SendCmd "FF0504[format %02X [expr $hr & 0xFF]]"
  after 15
}

# Set BlueRobin speed and distance value
proc BM_BR_SetSpeed { spd dist } {
  SendCmd "FF0A06[format %02X [expr $spd & 0xFF]][format %02X [expr $dist & 0xFF]][format %02X [expr ($dist>>8) & 0xFF]]"
  after 15
}

# Start SimpliciTI stack
proc BM_SPL_Start {} {
  SendCmd "FF0703"
  after 15
}

# Stop SimpliciTI stack
proc BM_SPL_Stop {} {
  SendCmd "FF0903"
  after 15
}

# Get 4 bytes payload from SimpliciTI stack
proc BM_SPL_GetData {} {
  global vcp_reply

  SendCmd "FF080700000000"
  after 15
  update
  
  while { [llength $vcp_reply] <= 6 } { 
    lappend vcp_reply 0x00
  }

  return [format "0x%02X" [expr ([lindex $vcp_reply 6]<<24) + ([lindex $vcp_reply 5]<<16) + ([lindex $vcp_reply 4]<<8) + [lindex $vcp_reply 3]]]
}


# Get HW status
proc BM_GetStatus {} {
  global vcp_reply vcp_pending vcp_debug fh
  SendCmd "FF000400"
  after 15
  update
  if { $vcp_debug == 1  } { puts $fh "BM_GetStatus = [lindex $vcp_reply 3]" }
  return [lindex $vcp_reply 3]
}


# Simulate mouse clicks
proc BM_SetMouseClick { btn } {
  global w

  set X [expr [winfo pointerx .]]
  set Y [expr [winfo pointery .]]
  set path [winfo containing $X $Y]

  switch $btn {
    1  { exec xdotool mousedown 1
         after 10 
         exec xdotool mouseup 1 }
    
    2  { exec xdotool mousedown 3
         after 10 
         exec xdotool mouseup 3 }
    
    3  { exec xdotool mousedown 1
         after 10 
         exec xdotool mouseup 1
         after 10
         exec xdotool mousedown 1
         after 10 
         exec xdotool mouseup 1 }
  }
}

# Simulate complex key events
proc BM_SetKey { keysymbol win alt ctrl shift } {
  global w

  # Press keys and release them immediately
  if { $win == 1 }   { exec xdotool keydown "Super_L" }
  if { $alt == 1 }   { exec xdotool keydown "Alt_L" }
  if { $ctrl == 1 }  { exec xdotool keydown "Control_L" }
  if { $shift == 1 } { exec xdotool keydown "Shift_L" }
  if { $keysymbol > 0 } { exec xdotool keydown $keysymbol }
  after 10
  if { $keysymbol > 0 } { exec xdotool keyup $keysymbol }
  if { $shift == 1 } { exec xdotool keyup "Shift_L" }
  if { $ctrl == 1 }  { exec xdotool keyup "Control_L" }
  if { $alt == 1 }   { exec xdotool keyup "Alt_L" }
  if { $win == 1 }   { exec xdotool keyup "Super_L" }
}


# Start SimpliciTI sync mode
proc BM_SYNC_Start {} {
  SndCmd "FF3003"
  after 15
}

# Send sync command
proc BM_SYNC_SendCommand { ldata } {

  # take data from list and append it to command
  set str "FF3116"
  set i 0
  foreach value $ldata {
     append str [format "%02X" $value]
     incr i
  }

  # byte stuff with 0x00 until 19 bytes are set
  for {set j $i} {$j < 19} {incr j} {  
   append str "00"
  }

  SendCmd $str
  after 15
}

# Get sync buffer
proc BM_SYNC_ReadBuffer {} {
  global vcp_reply

  SendCmd "FF3303"
  after 15
  update
  return [lrange $vcp_reply 3 22]
}

# Get sync buffer state (empty/full)
proc BM_SYNC_GetBufferStatus {} {
  global vcp_reply
 
  SendCmd "FF320400"
  after 15
  update
  return [lindex $vcp_reply 3]
}


# Get HW status
proc BM_GetStatus1 {} {
  global vcp_reply vcp_pending vcp_debug fh
  SendCmd "FF000400"
  while { $vcp_pending == 1 } { update }
  set reply [lindex $vcp_reply 3]
  if { $vcp_debug == 1  } { puts $fh "BM_GetStatus1 = $reply" }
  return $reply
}

# BM_WBSL_Start
proc BM_WBSL_Start { } {
  SendCmd "FF4003"
  after 15
}

# BM_WBSL_Stop
proc BM_WBSL_Stop { } {
  SendCmd "FF4603"
  after 15
}

# BM_WBSL_GetMaxPayload
proc BM_WBSL_GetMaxPayload { } {
  global vcp_reply vcp_pending vcp_debug fh

  SendCmd "FF490400"
  while { $vcp_pending == 1 } { update }
  if { $vcp_debug == 1  } { puts $fh "BM_WBSL_GetMaxPayload = [lindex $vcp_reply 3]" }
  return [lindex $vcp_reply 3]
}

# BM_WBSL_GetPacketStatus
proc BM_WBSL_GetPacketStatus { } {
  global vcp_reply vcp_pending vcp_debug fh

  SendCmd "FF480400"
  while { $vcp_pending == 1 } { update }
  if { $vcp_debug == 1  } { puts $fh "BM_WBSL_GetPacketStatus = [lindex $vcp_reply 3]" }
  return [lindex $vcp_reply 3]
}

# BM_WBSL_GetStatus
proc BM_WBSL_GetStatus { } {
  global vcp_reply vcp_pending vcp_debug fh
  
  SendCmd "FF410400"
  while { $vcp_pending == 1 } { update }
  if { $vcp_debug == 1  } { puts $fh "BM_WBSL_GetStatus = [lindex $vcp_reply 3]" }
  return [lindex $vcp_reply 3]
}

# BM_WBSL_SendData
proc BM_WBSL_SendData { data_or_info data } {
  global vcp_reply vcp_pending vcp_debug fh

  if { $data_or_info == 0 } {

    set byte0 "00"
    set byte1 [format %02X [expr $data&0xFF]]
    set byte2 [format %02X [expr $data>>8]]

    set str "FF4706$byte0$byte1$byte2"
    SendCmd $str
    return 3

  } else {

    # Send several packets until data has been transmitted
    if { $data_or_info == 1 } {  
      set byte0 "01" 
    } else {
      set byte0 "02" 
    }

    # Convert ASCII data string to hex values
    set len 0
    set data_to_send ""
    binary scan $data cu* valueList
    foreach value $valueList {
      append data_to_send [format "%02X" $value]
      incr len
    }

    set len1  [expr $len + 2]
    set byte1 [format %02X [expr $len&0xFF]]
    set data_to_send "$byte0$byte1$data_to_send"
    
    if { $vcp_debug == 1  } { puts $fh "\nBM_WBSL_SendData $data_to_send\n" }

    while { $len1 > 28 } {
      # Send 28 bytes 
      SendCmd "FF471F[string range $data_to_send 0 55]"
      # Cut away data that has been sent
      set data_to_send [string range $data_to_send 56 [string length $data_to_send]]
      set len1 [expr $len1-28]
      update
    }

    # Send last bytes 
    set len1 [expr [string length $data_to_send]/2 + 3]
    SendCmd "FF47[format %02X $len1]$data_to_send"
    update
    return $len1
  } 
}


