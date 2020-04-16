GlobalForward hOnEventStateChanged = null;
GlobalForward hOnPlayerWonEvent = null;
GlobalForward hOnPlayerParticipating = null;
GlobalForward hOnEventStarted = null;
GlobalForward hModifyDefaultOptions = null;
GlobalForward hHandleMenuOption = null;

stock void Register_Core_Forwards()
{
	hOnEventStateChanged = new GlobalForward("Eventinho_OnEventStateChanged", ET_Event, Param_Cell);
	hOnPlayerWonEvent = new GlobalForward("Eventinho_OnPlayerWonEvent", ET_Event, Param_Cell, Param_Cell);
	hOnPlayerParticipating = new GlobalForward("Eventinho_OnPlayerParticipating", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	hOnEventStarted = new GlobalForward("Eventinho_OnEventStarted", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	hModifyDefaultOptions = new GlobalForward("Eventinho_ModifyDefaultOptions", ET_Event, Param_String, Param_Cell);
	hHandleMenuOption = new GlobalForward("Eventinho_HandleMenuOption", ET_Event, Param_Cell, Param_String, Param_Cell, Param_String, Param_String, Param_Cell);
}