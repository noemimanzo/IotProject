
 
#include "LoraWAN.h"


configuration LoraWANAppC {}
implementation {
/****** COMPONENTS *****/
  components MainC, LoraWANC as App;
  //add the other components here
  
  
  
  /****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;
  
  /****** Wire the other interfaces down here *****/

}


