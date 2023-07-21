
/*
*	IMPORTANT:
*	The code will be avaluated based on:
*		Code design  
*
*/
 
 
#include "Timer.h"
#include "LoraWAN.h"


module LoraWANC @safe() {
  uses {
  
 	 /****** INTERFACES *****/
	interface Boot;
	interface Random;

    //Interfaces for communication
    interface Receive;
    interface AMSend;
    
	//Interfaces for timers
	interface Timer<TMilli> as Timer0;
	interface Timer<TMilli> as Timer1;
	
    //Other Interfaces;
    interface SplitControl as AMControl;
    interface Packet;
  }
}
implementation {

  message_t packet;
 
  bool locked;
  
  // Variables to handle the messages sent
  uint8_t id_index=1;
  lora_msg_t current_msg;
  
  uint8_t server_node =8;
  uint8_t current_msg_id;
  bool flag_ack = false;
  
  bool actual_send (uint16_t address, message_t* packet);
  
  
  /**** FUNCTIONS ****/
   
  bool actual_send (uint16_t address, message_t* packet){
  /*
  * This function is responsible for the actual transmission of a packet using the tinyOS interfaces. 
  * It checks if the sending process is currently locked and proceeds to send the packet if it is not. 
  * Upon successful transmission, it sets the lock flag. 
  */
  	lora_msg_t* packet_to_send = (lora_msg_t*) call Packet.getPayload(packet, sizeof(lora_msg_t));
	if (locked){ 
		return;
	} 
	else {	
		if (call AMSend.send(address, packet, sizeof(lora_msg_t))== SUCCESS) {
			locked=TRUE;
			dbg("radio_send", "Sending packet of type %d at time %s\n",packet_to_send->type,sim_time_string());

		}
	}
  }
  
  void fill_pkt(lora_msg_t* packet_to_fill, uint8_t type, uint8_t id, uint8_t sender, uint8_t content){
  /*
  * This function fills a packet by populating the fields of the `packet_to_fill` structure with the provided values according to its type.
  * In case of REQ, the sender and the cost_val are set to 0. 
  */
  	packet_to_fill -> type = type;
  	packet_to_fill -> id = id;
  	packet_to_fill -> sender = sender;
  	if (type == MSG){
  		packet_to_fill -> content = content;
  	}
  }
  
  /******* EVENTS ******/
  event void Boot.booted() {
    dbg("boot","Application booted.\n"); 
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
	if (err == SUCCESS) {
		dbg("radio","Radio on on node %d! at time %s\n", TOS_NODE_ID, sim_time_string());
	
		// Just in case of NODE=1,2,3,4,5 the timer is started
		if (TOS_NODE_ID != 6 || TOS_NODE_ID != 7 || TOS_NODE_ID != 8){
	  		call Timer0.startPeriodic(10000);
	  	}
	}
	else {
	  call AMControl.start();
	}
  }

  event void AMControl.stopDone(error_t err) {
    dbg("boot", "Radio stopped\n");
  }
  
  event void Timer0.fired() { // invio periodico
	// 1. creazione pack
	lora_msg_t* msg_to_send = (lora_msg_t*) call Packet.getPayload(&packet, sizeof(lora_msg_t));
	if (msg_to_send == NULL) {
			return;
	}
	msg_val= Random.rand16()% 100;
	fill_pkt(msg_to_send, MSG, id_index, TOS_NODE_ID, msg_val);
	
	// 2. salvo messaggio 
	current_msg.type = msg_to_send.type
	current_msg.id = msg_to_send.id
	current_msg.sender = msg_to_send.sender
	current_msg.content = msg_to_send.content
	
	// 3. invio broadcast +start timer1 (one shot)
	actual_send(AM_BROADCAST_ADDR, &packet);
	call Timer1.startOneShot(1000);
	id_index++;
  }
  
   event void Timer1.fired() { // check arrivo ack
	/* se flag = true (mi è arrivato in tempo)
			nulla
	   altrimenti
	   		rinvio messaggio broadcast + start timer 1(one shot) 	
	*/
	if (!flag_ack){ // flag = false msg is resent
		lora_msg_t* msg_to_send = (lora_msg_t*) call Packet.getPayload(&packet, sizeof(lora_msg_t));
		if (msg_to_send == NULL) {
				return;
		}
		fill_pkt(msg_to_send, current_msg.type, current_msg.id, current_msg.sender, current_msg.content);
		actual_send(AM_BROADCAST_ADDR, &packet);
		call Timer1.startOneShot(1000);
		
	}
  }

  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {
	/*
	case 1: ricezione mess
		node= gat
			fowarded to server
		node = server
			(check duplicati + salvataggio+invio nodered)
			invio ack
	
	case 2: ricezione ack
		node = gat
			fowarded ack (al sender del ack/msg)
		
		node = sensor
			check se ack è quello relativo al messaggio appena inviato
				flag = true
			se no flag sempre falso 	
			
	*/
	if (len != sizeof(lora_msg_t)) {return bufPtr;}
    else {
		lora_msg_t* current_pkt = (lora_msg_t*)payload;
		switch(current_pkt -> type) {
			case 0: //msg case
				lora_msg_t* packet_to_send= (lora_msg*) call Packet.getPayload(&packet, sizeof(lora_msg_t));
				if (packet_to_send== NULL) {
					return;
				}
				current_msg_id=current_pkt->id; 
				if (TOS_NODE_ID == server_node) { //if i am the server
					//check duplicates and store message
					
					//create ACK
					packet_to_send -> type = ACK;
					packet_to_send -> id = current_pkt-> id;
					packet_to_send -> sender = current_pkt-> sender;
					//send ACK to the gateway
					actual_send(current_pkt->gateway, &packet);

				} else { //if i am a gateway (not possible that a msg arrive to a sensor
					packet_to_send -> type = MSG;
					packet_to_send -> id = current_pkt-> id;
					packet_to_send -> sender = current_pkt-> sender;
					packet_to_send -> content = current_pkt -> content;
					actual_send(server_node, &packet);
				
				}
				return bufPtr;
				break;
			
			case 1: //ack case
				lora_msg_t* packet_to_send= (lora_msg*) call Packet.getPayload(&packet, sizeof(lora_msg_t));
				if (packet_to_send== NULL) {
					return;
				}
				if (TOS_NODE_ID == 6 || TOS_NODE_ID ==7) { //if i am a gateway
					packet_to_send -> type = ACK;
					packet_to_send -> id = current_pkt-> id;
					packet_to_send -> sender = current_pkt-> sender;
					//send ACK to the sensor
					actual_send(current_pkt->sender, &packet);
				} else { //if i am a sensor (not possible that a msg arrive to the server
					if(current_msg_id == current_pkt -> id && current_pkt->sender ==TOS_NODE_ID) {
					flag_ack=true;
					} else {
					flag_ack=false; 
					}
				}
				return bufPtr;
				break;
		}
    
  	}
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	if (&packet==bufPtr ) {
      locked = FALSE;
      dbg("radio_send", "Packet sent successfully!\n");
    }
  }
}




