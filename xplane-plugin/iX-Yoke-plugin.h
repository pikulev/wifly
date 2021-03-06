/*
 *  iX-Yoke-plugin.h
 *  Wi-Fly-plugin
 *
 *  Created by Daniel Dickison on 5/11/09.
 *  Copyright 2009 Daniel_Dickison. All rights reserved.
 *
 * 
 *  This file is part of Wi-Fly-plugin.
 *  
 *  Wi-Fly-plugin is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  
 *  Wi-Fly-plugin is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with Wi-Fly-plugin.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


#ifndef __IX_YOKE_PLUGIN_H
#define __IX_YOKE_PLUGIN_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/time.h>

#if IBM
#include <windows.h>
#include <process.h>
#define snprintf _snprintf
#define socklen_t int
size_t smbw_strlcat(char *dst, const char *src, size_t siz);
#define strlcat smbw_strlcat
#endif

#if APL || LIN
#include <pthread.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <unistd.h>
#include <netdb.h>
#define closesocket close
#define SOCKET_ERROR -1
#define NON_BLOCKING 1
#endif

#if LIN
#include <asm/ioctls.h>
#include <errno.h>
#endif


#include "XPLMPlugin.h"
#include "XPLMDataAccess.h"
#include "XPLMProcessing.h"
#include "XPLMUtilities.h"
#include "XPWidgetDefs.h"
#include "XPWidgets.h"
#include "XPWidgetUtils.h"
#include "XPStandardWidgets.h"
#include "XPWidgetsEx.h"
#include "XPLMMenus.h"


#include "iX_Yoke_Network.h"


// Returns a relative clock time with millisecond accuracy.
// The first call becomes the epoch time.
long get_ms_time();


#if APL
int MacToUnixPath(const char * inPath, char * outPath, int outPathMaxLen);
#endif

void iXDebug(char *str);

void update_overrides();



// Server.c

void start_server();
void stop_server();
char *get_server_error_string(); // Returns NULL if no msg.
void get_server_info(char *hostname, size_t hostname_size,
                     char *ips, size_t ips_size);


// The display strings corresponding to iXControlType.
#define axis_choices "Off;Pitch;Roll;Yaw;Roll and Yaw;Throttle;Prop Pitch;Speed Brake;Thrust Vector"

typedef enum {
    kAxisControlOff = 0,
    kAxisControlPitch,
    kAxisControlRoll,
    kAxisControlYaw,
    kAxisControlRollAndYaw,
    kAxisControlThrottle,
    kAxisControlPropPitch,
    kAxisControlSpeedBrake,
    kAxisControlVector
} iXControlType;


typedef struct {
    iXControlType type;
    float prev_value;
    float value;
    float min;
    float max;
    
    // UI stuff
    const char title[32];
    XPWidgetID popup_widget;
    XPWidgetID min_widget;
    XPWidgetID max_widget;
    XPWidgetID progress_widget;
    XPWidgetID reverse_widget;
} iXControlAxis;

typedef iXControlAxis * iXControlAxisRef;


typedef enum {
    kAxisTiltX = 0,
    kAxisTiltY,
    kAxisTouchX,
    kAxisTouchY,
    kNumAxes
} iXControlAxisID;



iXControlAxisRef get_axis(iXControlAxisID axis_id);
long get_last_packet_time();
int get_packet_rate();
int currently_connected();



// Prefs and Presets

#define MAX_USER_PRESETS 32

typedef enum {
    kPresetTypeNone = 0,
    kPresetTypeReadOnly = 1,
    kPresetTypeUser = 2,
    kPresetTypeBoth = 3
} iXPresetType;

void load_prefs();
void save_prefs();
int get_preset_names(iXPresetType types, char **outNames);
int current_preset(); // Returns -1 for "Custom".
void set_current_preset(int i); // Pass -1 for "Custom".
void save_preset(int preset_index, const char *inName);
void delete_preset(int i);
int get_pref_int(const char *inPrefName);
void set_pref_int(const char *inPrefName, int val);

extern const char * const kPrefCurrentPreset;
extern const char * const kPrefAutoPause;
extern const char * const kPrefAutoResume;


// Window

void show_window();
void destroy_window();
int update_window();



#endif
