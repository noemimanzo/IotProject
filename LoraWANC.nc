#include "Timer.h"
#include "LoraWAN.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>


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

//*************************** VARIABLES DEFINITION ***************************//
  message_t packet;
 
  bool locked= FALSE;
  
  // Variables to handle messages
  uint8_t id_index=1;
  uint8_t msg_val;
  saved_msg_t saved_msg;
  lora_msg_t current_msg;
  
  uint8_t current_type;
  uint8_t current_id;
  uint8_t current_sender;
  uint8_t current_content;
  
  uint8_t i=0;
  
  uint8_t server_node =8;
  bool flag_ack = FALSE;
  
  
  // Variables for TCP connection
  struct sockaddr_in address;  
  int server_fd, new_socket;
  int addrlen = sizeof(address);
  char message[100];
  int message_len;

  
  //Functions
  bool actual_send (uint16_t address, message_t* packet);
  void fill_pkt(lora_msg_t* packet_to_fill, uint8_t type, uint8_t id, uint8_t sender, uint8_t content, uint8_t gateway);
  int open_connection_tcp();  
  void save_send_msg(saved_msg_t save_msg,lora_msg_t* received_pkt, uint8_t index);
  void handle_msg(saved_msg_t save_msg,lora_msg_t* received_pkt);
  
    
//******************************** FUNCTIONS ********************************//
  //***************** SENDING MESSAGES *****************//
  bool actual_send (uint16_t address, message_t* packet){
  /*
  * This function is responsible for the actual transmission of a packet using the tinyOS interfaces. 
  * It checks if the sending process is currently locked and proceeds to send the packet if it is not. 
  * Upon successful transmission, it sets the lock flag. 
  */
  	lora_msg_t* packet_to_send = (lora_msg_t*) call Packet.getPayload(packet, sizeof(lora_msg_t));
	if (locked){ 
		dbg("radio_send","LOCKED!\n");
		return;
	} 
	else {	
		if (call AMSend.send(address, packet, sizeof(lora_msg_t))== SUCCESS) {
			locked=TRUE;
			dbg("radio_send","Sending packet of type %d at time %s toward node %d\n",packet_to_send->type,sim_time_string(),address, packet_to_send->gateway);

		}
	}
  }
  
  void fill_pkt(lora_msg_t* packet_to_fill, uint8_t type, uint8_t id, uint8_t sender, uint8_t content, uint8_t gateway){
  /*
  * This function fills a packet by populating the fields of the `packet_to_fill` structure with the provided values according to its type.
  */
  	packet_to_fill -> type = type;
  	packet_to_fill -> id = id;
  	packet_to_fill -> sender = sender;
  	if (type == MSG) {
	  	packet_to_fill -> content = content;
	  	packet_to_fill -> gateway = gateway;
	}
  }
  
  int open_connection_tcp(){
  /*
  * This function sets up a TCP server by creating a socket, binding it to a specific port. 
  * Once a connection is established, the function accepts the incoming connection and returns a new socket through which communication with the client can take place.
  */
  
    // Create TCP socket
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }
    
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(60002);
    
    // Bind the socket to localhost and port 60002
    if (bind(server_fd, (struct sockaddr*)&address, sizeof(address)) < 0) {
        perror("Bind failed");
        exit(EXIT_FAILURE);
    }
    
    // Listen for incoming connections
    if (listen(server_fd, 3) < 0) {
        perror("Listen failed");
        exit(EXIT_FAILURE);
    }
    
    // Accept incoming connection
    if ((new_socket = accept(server_fd, (struct sockaddr*)&address, (socklen_t*)&addrlen)) < 0) {
        perror("Accept failed");
        exit(EXIT_FAILURE);
    }
    
    return new_socket;
    
  }
  
  void save_send_msg(saved_msg_t save_msg,lora_msg_t* received_pkt, uint8_t index){
  /*
  * This function processes the received message and saves it into the structure saved_msg_t at the specific index.  
  * Additionally, it sends a message containing the saved data to a connected client via a previously established TCP socket.
  */
  
  	saved_msg.node[index] = received_pkt-> sender;
	saved_msg.id[index] = received_pkt-> id;
	saved_msg.content[index] = received_pkt -> content;
	
	sprintf(message, "NODE: %d ID: %d CONTENT: %d\n",saved_msg.node[index],saved_msg.id[index],saved_msg.content[index]);
	message_len = strlen(message);
	send(new_socket, message, message_len, 0);
  }
  
  void handle_msg(saved_msg_t save_msg,lora_msg_t* received_pkt){
  /*
  * This function handles the received messages. It determines whether to save and send the packet, overwrite previous data from the same sender if it's a new message, or handle a
  * duplicate message.
  */
  
  	uint8_t sensor_index  = received_pkt-> sender-1;
  	  	
  	// If table empty -> save msg
  	if(saved_msg.node[sensor_index]==0 && saved_msg.id[sensor_index]==0){
		save_send_msg(saved_msg,received_pkt,sensor_index);
				
	}
	// New msg arrived -> table whitened and new msg saved
	else if (saved_msg.id[sensor_index] != received_pkt->id){
		for (i=0; i<5; i++){
			saved_msg.node[i]=0;
			saved_msg.id[i]=0;
			saved_msg.content[i]=0;
		}
		save_send_msg(saved_msg,received_pkt,sensor_index);
	}
	// Duplicate arrived -> nothing
	else{
		dbg("server_node", "DUPLICATE FOUND!!!\n");
	}
  }
  
//********************************** EVENTS **********************************//

  //***************** BOOT INTERFACE *****************//
  event void Boot.booted() {
    dbg("boot","Application booted.\n"); 
    if (TOS_NODE_ID == 8){
		open_connection_tcp(); // Start tcp connection
		// Inizialize saved message table
		for (i=0; i<5; i++){
			saved_msg.node[i]=0;
			saved_msg.id[i]=0;
			saved_msg.content[i]=0;
    	}
    }
    call AMControl.start();
  }

  //***************** AM CONTROL INTERFACE *****************//
  event void AMControl.startDone(error_t err) {
	if (err == SUCCESS) {
		dbg("radio","Radio on on node %d! at time %s\n",TOS_NODE_ID,sim_time_string());
		
		// Just in case of sensor NODE the periodic timer is started
	  	if (TOS_NODE_ID < 6 ){
	  		call Timer0.startPeriodicAt(0,10000);
	  	}
	}
	else {
		call AMControl.start();
	}
  }

  event void AMControl.stopDone(error_t err) {
    dbg("boot", "Radio stopped\n");
  }
  

  //***************** TIMERS CONTROL *****************//
  event void Timer0.fired() { 
  /*
  * Timer for message creation
  */
  
	// 1. Creating message with random value
	lora_msg_t* msg_to_send = (lora_msg_t*) call Packet.getPayload(&packet, sizeof(lora_msg_t));
	if (msg_to_send == NULL) {
			return;
	}
	msg_val= (call Random.rand16()%200);
	fill_pkt(msg_to_send, MSG, id_index, TOS_NODE_ID, msg_val,0);
	
	// 2. Storing message to send
	current_type = msg_to_send->type;
	current_id = msg_to_send->id;
	current_sender = msg_to_send->sender;
	current_content = msg_to_send->content;
	
	dbg("sensor_node","CREATE MESSAGE\n\t\t\tTYPE: %d\n\t\t\tID: %d\n\t\t\tSENDER: %d\n\t\t\tCONTENT: %d\n",current_type,current_id,current_sender,current_content);	
		
	// 3. Sending message and starting timer
	actual_send(AM_BROADCAST_ADDR, &packet);	
	call Timer1.startOneShot(1000);
	id_index++;
	
  }
  
  event void Timer1.fired() { 
  /*
  * Timer for checking ack 
  */
  
  	// CASE 1: ack NOT arrived in time -> resend message 
	if (!flag_ack){ 
		lora_msg_t* msg_to_send = (lora_msg_t*) call Packet.getPayload(&packet, sizeof(lora_msg_t));	
		if (msg_to_send == NULL) {
				return;
		}
		dbg("sensor_node","TIME EXPIRED!\n");
		dbg("sensor_node","RESEND MSG with ID: %d and CONTENT: %d\n",current_id,current_content);
		fill_pkt(msg_to_send, current_type, current_id, current_sender, current_content, 0);
		actual_send(AM_BROADCAST_ADDR, &packet);
		call Timer1.startOneShot(1000);
		
	} 
	// CASE 2: ack arrived in time
	else {
		dbg("sensor_node","ACK ARRIVED CORRECTLY!\n");
		flag_ack= FALSE;	
	}
  }
  
  //***************** RECEIVE INTERFACE *****************//
  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {
  /*
  *  Here the logic after receiving a message is handled.
  *  Upon receiving a message, the received packet is parsed and specific actions based on the type of packet received are performed.	
  */
  
	if (len != sizeof(lora_msg_t) || locked ) {return bufPtr;}
    else {
	
		lora_msg_t* received_pkt = (lora_msg_t*)payload;
		
		/****** 1 - CASE RECEIVE A MSG ******/
		if (received_pkt -> type == MSG){
 			lora_msg_t* packet_to_send= (lora_msg_t*) call Packet.getPayload(&packet, sizeof(lora_msg_t));
			if (packet_to_send== NULL) {
				return;
			}
			// A. SERVER SIDE 			
			if (TOS_NODE_ID == server_node) {
				if(locked){return bufPtr;} 
				else{
    				
					dbg("server_node","MSG arrived at server %d from gateway %d\n \t\t\tSENDER: %d\n \t\t\tID: %d\n \t\t\tCONTENT:%d\n",TOS_NODE_ID,received_pkt->gateway,received_pkt-> sender,received_pkt->id,received_pkt->content);
					
					// 1) Checking and saving MSG
					handle_msg(saved_msg,received_pkt);
					
					dbg("server_node", "MSG SAVED IN TABLE\n\t\t\tNODE:%d,%d,%d,%d,%d\n",saved_msg.node[0], saved_msg.node[1], saved_msg.node[2], saved_msg.node[3], saved_msg.node[4]);
					dbg_clear("server_node","\t\t\tID:%d,%d,%d,%d,%d\n",saved_msg.id[0], saved_msg.id[1], saved_msg.id[2], saved_msg.id[3], saved_msg.id[4]);
					dbg_clear("server_node","\t\t\tCONTENT:%d,%d,%d,%d,%d\n",saved_msg.content[0], saved_msg.content[1], saved_msg.content[2], saved_msg.content[3], saved_msg.content[4]);
					
					// 2) Creating and sending ACK 
					fill_pkt(packet_to_send, ACK, received_pkt-> id, received_pkt-> sender, 0, 0);
					actual_send(received_pkt->gateway, &packet);
				}
			} 
			// B. GATEWAY SIDE (not possible that a MSG arrive to a sensor)
			else { 
				// 1) Forwarding MSG
				dbg("gateway_node","MSG arrived at gateway %d\n \t\t\tSENDER: %d\n \t\t\tID: %d\n \t\t\tCONTENT:%d\n",TOS_NODE_ID,received_pkt->sender,received_pkt->id, received_pkt-> content);
				fill_pkt(packet_to_send, MSG, received_pkt-> id, received_pkt-> sender,received_pkt -> content , TOS_NODE_ID);
				actual_send(server_node, &packet);
			}
			
		}
		
		/****** 2 - CASE RECEIVE AN ACK ******/
		else {
			lora_msg_t* packet_to_send= (lora_msg_t*) call Packet.getPayload(&packet, sizeof(lora_msg_t));
			if (packet_to_send== NULL) {
				return;
			}
			// A. GATEWAY SIDE
			if (TOS_NODE_ID == 6 || TOS_NODE_ID ==7) { 
				// 1) Forwarding ACK
				dbg("gateway_node","ACK ARRIVED at gateway %d\n \t\t\tSENDER: %d\n \t\t\tID: %d\n",TOS_NODE_ID, received_pkt-> sender, received_pkt-> id);
				fill_pkt(packet_to_send, ACK, received_pkt-> id, received_pkt-> sender, 0, 0);
				actual_send(received_pkt->sender, &packet);
			} 
			// B. SENSOR SIDE (not possible that an ACK arrive to the server)
			else {
				// 1) Setting flag for ACK check
				dbg("sensor_node","ACK ARRIVED at node %d\n \t\t\tSENDER: %d\n \t\t\tID: %d\n", TOS_NODE_ID, received_pkt->sender, received_pkt -> id );
				if(current_id == received_pkt -> id && received_pkt->sender ==TOS_NODE_ID) {
					flag_ack=TRUE;
				} else {
					flag_ack=FALSE; 
				}
			}
		}
		return bufPtr;
    
  	}
  
  }

  //***************** SEND INTERFACE *****************//
  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	if (&packet==bufPtr) {
      locked = FALSE;
      dbg("radio_send", "Packet sent successfully!\n");
    }
  }
}




