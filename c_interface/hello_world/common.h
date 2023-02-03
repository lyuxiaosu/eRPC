#ifndef COMMON_H__
#define COMMON_H__

#include "erpc_c_interface.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char kServerHostname[] = "128.110.218.241";
static const char kClientHostname[] = "128.110.218.246";

static const char kUDPPort[] = "31850";
static const uint8_t kReqType = 2;
static const size_t kMsgSize = 16;

char* append(const char* str1, const char* str2) {		
	char* result = malloc(strlen(str1) + strlen(str2) + 1); /* make space for the new string (should check the return value ...) */
	strcpy(result, str1); /* copy name into the new var */
	strcat(result, str2); /* add the extension */
	return result;
}

#endif /*COMMON_H__*/
