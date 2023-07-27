

#ifndef LORAWAN_H
#define LORAWAN_H

// Message structure
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

// Saved message table structure
typedef nx_struct saved_msg{
	nx_uint8_t node[5];
	nx_uint8_t id[5];
	nx_uint8_t content[5];
}saved_msg_t; 
#endif
