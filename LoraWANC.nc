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
	//interface Timer<TMilli> as TimerDelay;
	//interface Timer<TMilli> as Timer2;
	
    //Other Interfaces;
    interface SplitControl as AMControl;
    interface Packet;
  }
}
implementation {

  message_t packet;
 
  bool locked= FALSE;
  
  // Variables to handle the messages sent
  uint8_t id_index=1;
  lora_msg_t current_msg;
  uint8_t msg_val;
  uint16_t time_delays[5]={61,173,267,371,479};
  saved_msg_t saved_msg;
  
  uint8_t current_type;
  uint8_t current_id;
  uint8_t current_sender;
  uint8_t current_content;
  
  uint8_t i=0;
  
  uint8_t server_node =8;
 // uint8_t current_msg_id;
  bool flag_ack = FALSE;
  
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
		dbg("radio_send", "LOCKED!!!!\n");
		return;
	} 
	else {	
		if (call AMSend.send(address, packet, sizeof(lora_msg_t))== SUCCESS) {
			locked=TRUE;
			dbg("radio_send", "Sending packet of type %d at time %s toward node %d gateInPkt: %d sender: %d content %d\n",packet_to_send->type,sim_time_string(), address, packet_to_send->gateway, packet_to_send->sender, packet_to_send->content);

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
  	packet_to_fill -> content = content;
  	packet_to_fill -> gateway = gateway;
  	
  }
  
  /******* EVENTS ******/
  event void Boot.booted() {
    dbg("boot","Application booted.\n"); 
    if (TOS_NODE_ID == 8){
		for (i=0; i<5; i++){
			saved_msg.node[i]=0;
			saved_msg.id[i]=0;
			saved_msg.content[i]=0;
    	}
    }
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
	if (err == SUCCESS) {
		dbg("radio","Radio on on node %d! at time %s\n", TOS_NODE_ID, sim_time_string());
	
		// Just in case of NODE=1,2,3,4,5 the timer is started
		/*if (TOS_NODE_ID == 1 || TOS_NODE_ID == 2 || TOS_NODE_ID == 3 || TOS_NODE_ID == 4 || TOS_NODE_ID == 5 ){
	  		call Timer0.startPeriodic(10000);
	  	}
	  	*/
	  	if (TOS_NODE_ID == 1 || TOS_NODE_ID == 2 || TOS_NODE_ID == 3 || TOS_NODE_ID == 4 || TOS_NODE_ID == 5 ){
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
  
  /*event void TimerDelay.fired (){
 	
  }
  */
  
  event void Timer0.fired() { // invio periodico
	// 1. creazione pack
	lora_msg_t* msg_to_send = (lora_msg_t*) call Packet.getPayload(&packet, sizeof(lora_msg_t));
	if (msg_to_send == NULL) {
			return;
	}
	msg_val= (call Random.rand16())% 100;
	//call TimerDelay.startOneShot(time_delays[TOS_NODE_ID-1]);

	dbg("radio_rec","random value at node %d: %d\n", TOS_NODE_ID, msg_val);	
	fill_pkt(msg_to_send, MSG, id_index, TOS_NODE_ID, msg_val,0);
	
	
	// 2. salvo messaggio 
	current_type = msg_to_send->type;
	current_id = msg_to_send->id;
	current_sender = msg_to_send->sender;
	current_content = msg_to_send->content;
	
	dbg("radio_rec","current msg -> type: %d id: %d sender: %d content: %d\n", current_type, current_id, current_sender, current_content);	
	
	
	// 3. invio broadcast +start timer1 (one shot)
	actual_send(AM_BROADCAST_ADDR, &packet);
	dbg("radio_rec","	msg sent at node %d\n", TOS_NODE_ID);	
	call Timer1.startOneShot(1000);
	id_index++;
	
  }
  
  event void Timer1.fired() { // check arrivo ack
	/* se flag = true (mi è arrivato in tempo)
			nulla
	   altrimenti
	   		rinvio messaggio broadcast + start timer 1(one shot) 	
	*/
	dbg("radio_rec","	flag : %d\n", flag_ack);	
	if (!flag_ack){ // flag = false msg is resent
		lora_msg_t* msg_to_send = (lora_msg_t*) call Packet.getPayload(&packet, sizeof(lora_msg_t));	
		if (msg_to_send == NULL) {
				return;
		}
		dbg("radio_rec","TIME EXPIRED\n");
		dbg("radio_rec","RESEND MSG: type: %d id: %d sender: %d content: %d\n", current_type, current_id, current_sender, current_content);
		fill_pkt(msg_to_send, current_type, current_id, current_sender, current_content,0);
		actual_send(AM_BROADCAST_ADDR, &packet);
		call Timer1.startOneShot(1000);
		
	} else {
	dbg("radio_rec","ACK arrived corrected \n");
	flag_ack= FALSE;	
	}
  }
  
  /*event void Timer2.fired() {
 	actual_send (queue_addr, &queued_packet);
  }
  */

 
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
	if (len != sizeof(lora_msg_t) || locked ) {return bufPtr;}
    else {
	
		lora_msg_t* received_pkt = (lora_msg_t*)payload;
		//printf("Packet received at node %d from node %d\n",TOS_NODE_ID, received_pkt->sender);
		//printfflush();
		//MSG CASE
		if (received_pkt -> type == MSG){
 			lora_msg_t* packet_to_send= (lora_msg_t*) call Packet.getPayload(&packet, sizeof(lora_msg_t));
			if (packet_to_send== NULL) {
				return;
			}
			//case1				
			if (TOS_NODE_ID == server_node) {
				if(locked){return bufPtr;} 
				else{//if i am the server
					dbg("radio_rec","MSG arrived at server %d from gateway %d\n \t\t\tid: %d\n \t\t\tsender: %d\n \t\t\tcontent:%d\n", TOS_NODE_ID,received_pkt -> gateway, received_pkt-> id, received_pkt->sender,received_pkt-> content );
					
					//check duplicates and store message
					if(saved_msg.node[received_pkt-> sender-1]==0 && saved_msg.id[received_pkt-> sender-1]==0){
						saved_msg.node[received_pkt-> sender-1] = received_pkt-> sender;
						saved_msg.id[received_pkt-> sender -1] = received_pkt-> id;
						saved_msg.content[received_pkt-> sender -1] = received_pkt -> content;
						//printf("NODE:%d,ID:%d,CONTENT:%d!\n",saved_msg.node[received_pkt->sender-1], saved_msg.id[received_pkt-> sender -1],saved_msg.content[received_pkt-> sender -1]);
						//printfflush();
					}
					else if (saved_msg.id[received_pkt-> sender-1] != received_pkt->id){
						for (i=0; i<5; i++){
							saved_msg.node[i]=0;
							saved_msg.id[i]=0;
							saved_msg.content[i]=0;
						}
						saved_msg.node[received_pkt-> sender-1] = received_pkt-> sender;
						saved_msg.id[received_pkt-> sender -1] = received_pkt-> id;
						saved_msg.content[received_pkt-> sender -1] = received_pkt -> content;
						//printf("NODE:%d,ID:%d,CONTENT:%d!\n",saved_msg.node[received_pkt->sender-1], saved_msg.id[received_pkt-> sender -1],saved_msg.content[received_pkt-> sender -1]);
						//printfflush();
					}
					else{
						dbg("radio_rec", "DUPLICATE FOUND!!!\n");
					}
						
					/*if(saved_msg.node[received_pkt-> sender-1] != received_pkt-> sender && saved_msg.id[received_pkt-> sender-1] != received_pkt-> id){
						saved_msg.node[received_pkt-> sender-1] = received_pkt-> sender;
						saved_msg.id[received_pkt-> sender -1] = received_pkt-> id;
						saved_msg.content[received_pkt-> sender -1] = received_pkt -> content;
						//printf("NODE:%d,ID:%d,CONTENT:%d!\n",saved_msg.node[received_pkt-> sender-1], saved_msg.id[received_pkt-> sender -1],saved_msg.content[received_pkt-> sender -1]);
						//printfflush();
					} else {
						dbg("radio_rec", "DUPLICATE FOUND!!!\n");
					}*/
					dbg("radio_rec", "MSG SAVED TABLE\n\t\t\tNODE:%d,%d,%d,%d,%d\n", saved_msg.node[0],saved_msg.node[1],saved_msg.node[2],saved_msg.node[3],saved_msg.node[4]);
					dbg_clear("radio_rec","\t\t\tID:%d,%d,%d,%d,%d\n",saved_msg.id[0],saved_msg.id[1],saved_msg.id[2],saved_msg.id[3],saved_msg.id[4]);
					dbg_clear("radio_rec","\t\t\tCONTENT:%d,%d,%d,%d,%d\n",saved_msg.content[0],saved_msg.content[1],saved_msg.content[2],saved_msg.content[3],saved_msg.content[4]);
					
					//create ACK
					fill_pkt(packet_to_send, ACK, received_pkt-> id, received_pkt-> sender,received_pkt-> content , received_pkt -> gateway);
					//send ACK to the gateway
					actual_send(received_pkt->gateway, &packet);
					dbg("radio_rec","GATEWAY: %d\n",received_pkt->gateway); 
					//dbg("radio_rec","ACK sent from server %d\n", TOS_NODE_ID);
				}
			} 
			//case2
			else { //if i am a gateway (not possible that a msg arrive to a sensor
				dbg("radio_rec","MSG arrived at gat %d from node %d\n \t\t\tid: %d\n \t\t\tcontent:%d\n",TOS_NODE_ID,received_pkt-> sender,received_pkt-> id, received_pkt-> content );
				fill_pkt(packet_to_send, MSG, received_pkt-> id, received_pkt-> sender,received_pkt -> content , TOS_NODE_ID);
				actual_send(server_node, &packet);
				//dbg("radio_rec","msg sent from gat %d\n", TOS_NODE_ID);
			}
			
		}
		// ACK CASE
		else {
			lora_msg_t* packet_to_send= (lora_msg_t*) call Packet.getPayload(&packet, sizeof(lora_msg_t));
			if (packet_to_send== NULL) {
				return;
			}
			//case1
			if (TOS_NODE_ID == 6 || TOS_NODE_ID ==7) { //if i am a gateway
				dbg("radio_rec","ACK arrived at gat %d\n \t\t\tgateway: %d\n \t\t\tid: %d\n \t\t\tsender: %d\n \t\t\tcontent: %d\n", TOS_NODE_ID, received_pkt-> gateway, received_pkt-> id, received_pkt-> sender, received_pkt-> content);
				fill_pkt(packet_to_send, ACK, received_pkt-> id, received_pkt-> sender, 0, 0);
				//send ACK to the sensor
				actual_send(received_pkt->sender, &packet);
				//dbg("radio_rec","ACK sent from gat %d\n", TOS_NODE_ID);
			} 
			//case2
			else if(TOS_NODE_ID == 1 || TOS_NODE_ID == 2 || TOS_NODE_ID == 3 || TOS_NODE_ID == 4 || TOS_NODE_ID == 5){ //if i am a sensor (not possible that a ack arrive to the server
				dbg("radio_rec","ACK arrived at node %d\n \t\t\tsender: %d\n \t\t\tid: %d\n", TOS_NODE_ID,received_pkt->sender,received_pkt -> id );
				dbg("radio_rec","CHECK ID ACK: id_msgSent: %d  id_ackReceived: %d\n",current_id, received_pkt -> id);  
				if(current_id == received_pkt -> id && received_pkt->sender ==TOS_NODE_ID) {
					flag_ack=TRUE;
					dbg("radio_rec","flag check %d\n", flag_ack);
				} else {
					flag_ack=FALSE; 
					dbg("radio_rec","flag check %d\n", flag_ack);
				}
			}
		}
		return bufPtr;
    
  	}
  
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	if (&packet==bufPtr) {
      locked = FALSE;
      //dbg("radio_send", "Packet sent successfully!\n");
    }
  }
}




