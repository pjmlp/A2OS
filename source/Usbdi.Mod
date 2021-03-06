MODULE Usbdi; (** AUTHOR "staubesv"; PURPOSE "USB Driver Interface"; *)
(**
 * A2 USB Driver Interface
 *
 * This is the interface between USB device drivers and the A2 USB system software. If you want to develop a USB device
 * driver, be sure you don't miss the following ressources:
 *
 *	UsbSkeleton.Mod	USB device driver skeleton
 *
 * Overview:
 *
 *	Driver			Base class of USB device drivers, provides access to UsbDevice object
 *	UsbDevice		Abstraction of USB device, provides access to device descriptors and USB pipes
 *	Pipe			Communication channel used to send/receive data. Association of device endpoint and client buffer
 *	DriverManager	Keeps track of loaded USB device drivers
 *)

IMPORT Plugins;

CONST

	(** Result codes for USB transfers *)

	Ok* = 0;			(** Transfer completed without errors *)
	ShortPacket* = 1;	(** Device sent less data than requested *)
	Stalled* = 2;		(** Pipe stalled -> needs to be cleared using the Clearhalt request before communication can continue *)
	InProgress* = 3;		(** Transfer is still ongoing. For blocking transfers this means a timeout occured *)
	Error* = 4;			(** Unrecoverable Error *)
	Disconnected* = 5;	(** Device not connected to the bus anymore *)

	(** Coding of the EndpointDescriptor.type field *)
	Control* = 0;
	BulkIn* = 1;	BulkOut* = 2;
	InterruptIn* = 3; InterruptOut* = 4;
	IsochronousIn* = 5; IsochronousOut* = 6;

	(** bmRequestType encoding for control transfers *)

	(** Request direction *)
	ToDevice* = {}; ToHost* = {7};

	(** Request type *)
	Standard* = {}; Class* = {5}; Vendor* = {6};

	(** Request recipient *)
	Device* = {}; Interface* = {0}; Endpoint* = {1}; Other* = {0,1};

	(** Pipe modes *)

	Normal* = 0;			(** Poll pipe status and Yield() if transfer still in progress, slow transfers & less CPU time needed *)
	MaxPerformance* = 1;	(** Poll pipe status continuously, fast transfers & more CPU time needed *)
	MinCpu* = 2;			(** Don't poll pipe status - use interrupt notification, slow transfers & minimal CPU workload *)

TYPE

	Name* = Plugins.Name;
	Description* = Plugins.Description;

	Buffer* = ARRAY OF CHAR;
	BufferPtr* = POINTER TO Buffer;

	Status* = SIGNED32;

TYPE

	(** Consider all fields of all descriptors as read-only! *)

	DeviceDescriptor* = POINTER TO RECORD
		bcdUSB* : SIGNED32;
		bDeviceClass* : SIGNED32;
		bDeviceSubClass* : SIGNED32;
		bDeviceProtocol* : SIGNED32;
		idVendor* : SIGNED32;
		idProduct* : SIGNED32;
		bcdDevice* : SIGNED32;
		bNumConfigurations* : SIGNED32;
	END;

	(** 	A configuration is a set of interfaces. *)
	ConfigurationDescriptor* = POINTER TO RECORD
		bNumInterfaces* : SIGNED32;
		bConfigurationValue* : SIGNED32;
		interfaces* : POINTER TO ARRAY OF InterfaceDescriptor;
		iads* : Iads; (* Optional Interface Association Descriptors *)
		unknown* : UnknownDescriptor; (* Optional Class-specific descriptors *)
	END;

	(**	An interface is a set of endpoints. Device driver are typically bound to interfaces *)
	InterfaceDescriptor* = POINTER TO RECORD
		bInterfaceNumber* : SIGNED32;
		bAlternateSetting* : SIGNED32;
		bNumEndpoints* : SIGNED32;
		bInterfaceClass* : SIGNED32;
		bInterfaceSubClass* : SIGNED32;
		bInterfaceProtocol* : SIGNED32;
		numAlternateInterfaces* : SIGNED32;
		alternateInterfaces*: POINTER TO ARRAY OF InterfaceDescriptor;
		endpoints* : POINTER TO ARRAY OF EndpointDescriptor;
		unknown* : UnknownDescriptor;
	END;

	(**	Descriptor of a logical communication endpoint. USB pipe can be allocated for all endpoints using the endpoint
		address field *)
	EndpointDescriptor* = POINTER TO RECORD
		type* : SIGNED32; (* Control, BulkIn, BulkOut, InterruptIn, InterruptOut, IsochronousIn or IsochronousOut *)
		bEndpointAddress* : SIGNED32;
		wMaxPacketSize* : SIGNED32;
		bmAttributes* : SET;
		unknown* : UnknownDescriptor;
	END;

	(**	An optional Interface Association Descriptor describes a set of associated interfaces which should be handled by
		a single device driver. *)
	InterfaceAssociationDescriptor* = POINTER TO RECORD;
		bFirstInterface* : SIGNED32;
		bInterfaceCount* : SIGNED32;
		bFunctionClass* : SIGNED32;
		bFunctionSubClass* : SIGNED32;
		bFunctionProtocol* : SIGNED32;
	END;

	(** Optional non-USB-Standard descriptors.
		Linked list of optional descriptors contained in the configuration descriptor but not specified in the USB specification.
		UnknownDescriptors can be located at configuration, interface or endpoint level *)
	UnknownDescriptor* = POINTER TO RECORD;
		bLength* : SIGNED32;
		bDescriptorType* : SIGNED32;
		descriptor* : BufferPtr; (* contains bLength and bDescriptorType *)
		next* : UnknownDescriptor;
	END;

TYPE

	(** USB device driver base class *)
	Driver* = OBJECT(Plugins.Plugin)
	VAR
		(** The fields below will be initialized by the USB driver before the driver's Connect procedure is called *)

		(** Provides access to USB pipes and all the devices' descriptors *)
		device* : UsbDevice;

		(** Most often, a device driver is bound to one interface of the device. This is its descriptor. *)
		interface* : InterfaceDescriptor;

		(** This procedure is called by the USB driver when this object has been returned by the probe() procedure *)

		PROCEDURE Connect*() : BOOLEAN;
		BEGIN HALT(301); RETURN FALSE; END Connect; (* abstract *)

		(** This procedure is called by the USB driver when the device is detached. Note that the allocated pipes will be freed automatically *)

		PROCEDURE Disconnect*;
		BEGIN HALT(301); END Disconnect; (* abstract *)

	END Driver;

TYPE

	Configurations* = POINTER TO ARRAY OF ConfigurationDescriptor;

	Iads* = POINTER TO ARRAY OF InterfaceAssociationDescriptor;

TYPE

	UsbDevice* = OBJECT
	VAR
		(** Consider all fields of this object as read-only!! *)

		(** Device descriptor *)
		descriptor* : DeviceDescriptor;

		(** Device configurations *)
		configurations* : Configurations;

		(** Currently selected device configuration *)
		actConfiguration* : ConfigurationDescriptor;

		(** Device state *)
		state* : SIGNED32;

		(** Direct access to the Default Control Pipe (endpoint zero). Concurrent access is allowed here. *)

		PROCEDURE Request*(bmRequestType : SET;  bRequest, wValue, wIndex : SIGNED32; wLength : SIZE; VAR buffer : Buffer) : Status;
		BEGIN HALT(301); RETURN Error; END Request; (* abstract *)

		(** Allocate a pipe for the specified USB device endpoint *)

		PROCEDURE GetPipe*(endpoint : SIGNED32) : Pipe;
		BEGIN HALT(301); RETURN NIL; END GetPipe; (* abstract *)

		(**	Deallocate the ressources associtated with the specified pipe.
			Note: This is done automatically for device drivers after their Disconnect procedure has been called. *)

		PROCEDURE FreePipe*(pipe : Pipe);
		BEGIN HALT(301); END FreePipe; (* abstract *)

	END UsbDevice;

TYPE

	(** Handler that can be installed for a pipe and will be called when the USB transfer has been processed. *)
	CompletionHandler* = PROCEDURE {DELEGATE} (status : Status; actLen : SIZE);

	(**	USB Communication Pipe
	 	USB communication happens between buffers provided by client software and USB device endpoints. The association between
	 	a client software buffer and a specific USB device endpoint is called pipe. *)
	Pipe* = OBJECT
	VAR
	 	(**	How many tries should the host controllers retry the USB transaction if it fails. Note that this field is actually depended
	 		on the host controller used. Typically, the allowed range of this value is [0,3], zero meaning infinite number of retries *)
		maxRetries* : SIGNED32;

		(** Maximum packet size supported by endpoint. This field is set by the USB driver and should be considered read-only. *)
		maxPacketSize* : SIGNED32;

		mode* : SIGNED32;

		(** Transfer 'bufferLen' bytes from/to the specified buffer, starting at 'offset' *)

		PROCEDURE Transfer*(bufferLen, offset : SIZE; VAR buffer : Buffer) : Status;
		BEGIN HALT(301); RETURN Error; END Transfer; (* abstract *)

		(** For control transfers (only for Control Pipes) *)

		PROCEDURE Request*(bmRequestType : SET;  bRequest, wValue, wIndex : SIGNED32; wLength : SIZE; VAR buffer : Buffer) : Status;
		BEGIN HALT(301); RETURN Error; END Request; (* abstract *)

		(** Is the halt feature of the endpoint associated with this pipe set? *)

		PROCEDURE IsHalted*() : BOOLEAN;
		BEGIN HALT(301); RETURN FALSE; END IsHalted; (* abstract *)

		(** Clear halt feature of endpoint associated with this pipe. *)

		PROCEDURE ClearHalt*() : BOOLEAN;
		BEGIN HALT(301); RETURN FALSE; END ClearHalt; (* abstract *)

		(** Set timeout for transfers for this pipe;  0 = NonBlocking, n = n milliseconds *)

		PROCEDURE SetTimeout*(timeout : SIGNED32);
		BEGIN HALT(301); END SetTimeout; (* abstract *)

		(** Specifiy the completion handler that is called when the USB transfer is processed. *)

		PROCEDURE SetCompletionHandler*(handler: CompletionHandler);
		BEGIN HALT(301); END SetCompletionHandler;

		(** Update and return the status of the current USB transfer.
		 	@param actLen: Number of bytes that have been sent/receive (only valid if status * ResInProgress = {})
		 	@return: Status of the USB transfer *)

		PROCEDURE GetStatus*(VAR actLen : SIZE) : Status;
		BEGIN HALT(301); RETURN Error; END GetStatus; (* abstract *)

		(** Return the actual number of bytes transfered. *)

		PROCEDURE GetActLen*() : SIZE;
		BEGIN HALT(301); RETURN 0; END GetActLen; (* abstract *)

		(** Show debug information for this pipe. In detailed mode, the scheduling data structures related to
			this pipe will be shown (QH and TD list) *)

		PROCEDURE Show*(detailed : BOOLEAN);
		BEGIN HALT(301); END Show; (* abstract *)

	END Pipe;

TYPE

	(** The USB driver will call the Probe procedure for each interface of the device *)
	ProbeProc* = PROCEDURE {DELEGATE} (device : UsbDevice; interface : InterfaceDescriptor) : Driver;

	(** This object manages USB device drivers. All device drivers registered at the driver manager are automatically mapped to
		appropriate USB functions. *)
	DriverManager* = OBJECT

		(** Add a USB device driver to the internal registry. Driver names have to be unique and no longer than 30 characters (incl. Null-String) *)

		PROCEDURE Add*(probe : ProbeProc; CONST name: Plugins.Name; CONST desc: Plugins.Description; priority : SIGNED32);
		BEGIN HALT(301); END Add; (* abstract *)

		(** Calls Disconnect of all instances of the driver. All instances are removed from the usbDrivers registry
			and the device driver is removed from the internal registry  *)

		PROCEDURE Remove*(CONST name : Plugins.Name);
		BEGIN HALT(301); END Remove; (* abstract *)

	END DriverManager;

VAR
	(** Can be used if you need to pass an VAR parameter argument which is not used *)
	NoData* : ARRAY 1 OF CHAR;

	(** Instantiated by USB driver; consider read-only *)
	drivers* : DriverManager;

END Usbdi.
