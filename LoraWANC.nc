
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
  
  bool actual_send (uint16_t address, message_t* packet);
  
  bool actual_send (uint16_t address, message_t* packet){
  /*
  * This function is responsible for the actual transmission of a packet using the tinyOS interfaces. 
  * It checks if the sending process is currently locked and proceeds to send the packet if it is not. 
  * Upon successful transmission, it sets the lock flag. 
  */
  	radio_route_msg_t* packet_to_send = (radio_route_msg_t*) call Packet.getPayload(packet, sizeof(radio_route_msg_t));
	if (locked){ 
		return;
	} 
	else {	
		if (call AMSend.send(address, packet, sizeof(radio_route_msg_t))== SUCCESS) {
			locked=TRUE;
			dbg("radio_send", "Sending packet of type %d at time %s\n",packet_to_send->type,sim_time_string());

		}
	}
  }
  
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
	// creazione pack
	// salvo messaggio 
	// invio broadcast +start timer1 (one shot)
  }
  
   event void Timer1.fired() { // check arrivo ack
	/* se flag = true (mi è arrivato in tempo)
			nulla
	   altrimenti
	   		rinvio messaggio broadcast + start timer 1(one shot) 	
	*/
			
		
  }

  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {
	/*
	case 1: ricezione mess
		node= gat
			fowarded to server
		node = server
			(check duplicati + salvataggio+invio nodered)
			ack
	
	case 2: ricezione ack
		node = gat
			fowarded (al sender del ack/msg)
		
		node = sensor
			check se ack è quello relativo al messaggio appena inviato
				flag = true
			se no flag sempre falso 	
			
	*/
	
    
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	/* This event is triggered when a message is sent 
	*  Check if the packet is sent 
	*/ 
  }
}




