

#ifndef LORAWAN_H
#define LORAWAN_H

//message structure
typedef nx_struct lora_msg {
	nx_uint8_t type;
	nx_uint8_t id;
	nx_uint8_t sender;
	nx_uint8_t content;	
	nx_uint8_t gateway;
} lora_msg_t;

#define MSG 0
#define ACK 1

enum {
  AM_LORA_COUNT_MSG = 10,
};

#endif
