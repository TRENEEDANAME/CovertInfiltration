//---------------------------------------------------------------------------------------
//  AUTHOR:  Xymanek and robojumper
//  PURPOSE: Houses X2EventListenerTemplates that affect UI. Mostly CHL hooks
//---------------------------------------------------------------------------------------
//  WOTCStrategyOverhaul Team
//---------------------------------------------------------------------------------------

class X2EventListener_Infiltration_UI extends X2EventListener;

var localized string strInfiltrationReady;
var localized string strCanWaitForBonusOrLaunch;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateGeoscapeListeners());
	Templates.AddItem(CreateAvengerHUDListeners());
	Templates.AddItem(CreateEventQueueListeners());
	Templates.AddItem(CreateArmoryListeners());
	Templates.AddItem(CreateSquadSelectListeners());
	Templates.AddItem(CreateStrategyPolicyListeners());

	return Templates;
}

////////////////
/// Geoscape ///
////////////////

static function CHEventListenerTemplate CreateGeoscapeListeners()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'Infiltration_UI_Geoscape');
	Template.AddCHEvent('Geoscape_ResInfoButtonVisible', GeoscapeResistanceButtonVisible, ELD_Immediate);
	Template.AddCHEvent('CovertAction_CanInteract', CovertAction_CanInteract, ELD_Immediate);
	Template.AddCHEvent('CovertAction_ShouldBeVisible', CovertAction_ShouldBeVisible, ELD_Immediate);
	Template.AddCHEvent('CovertAction_ActionSelectedOverride', CovertAction_ActionSelectedOverride, ELD_Immediate);
	Template.AddCHEvent('CovertAction_ModifyNarrativeParamTag', CovertAction_ModifyNarrativeParamTag, ELD_Immediate);
	Template.AddCHEvent('OnGeoscapeEntry', OnGeoscapeEntry);
	Template.AddCHEvent('CovertActionCompleted', CovertActionCompleted); // On submitted as we are going to pause geoscape which will cause a gamestate
	Template.RegisterInStrategy = true;

	return Template;
}

static protected function EventListenerReturn GeoscapeResistanceButtonVisible(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_FacilityXCom FacilityState;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none || Tuple.Id != 'Geoscape_ResInfoButtonVisible') return ELR_NoInterrupt;

	FacilityState = `XCOMHQ.GetFacilityByName('ResistanceRing');
	Tuple.Data[0].b = FacilityState != none && !Tuple.Data[1].b;
	
	return ELR_NoInterrupt;
}

static protected function EventListenerReturn CovertAction_CanInteract(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_CovertAction Action;
	local XComLWTuple Tuple;

	Action = XComGameState_CovertAction(EventSource);
	Tuple = XComLWTuple(EventData);

	if (Action == none || Tuple == none || Tuple.Id != 'CovertAction_CanInteract') return ELR_NoInterrupt;

	// All CAs can be interacted with
	Tuple.Data[0].b = true;
	
	return ELR_NoInterrupt;
}

static protected function EventListenerReturn CovertAction_ShouldBeVisible(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_CovertAction Action;
	local XComLWTuple Tuple;

	Action = XComGameState_CovertAction(EventSource);
	Tuple = XComLWTuple(EventData);

	if (Action == none || Tuple == none || Tuple.Id != 'CovertAction_ShouldBeVisible') return ELR_NoInterrupt;

	Tuple.Data[0].b = class'UIUtilities_Infiltration'.static.ShouldShowCovertAction(Action);
	
	return ELR_NoInterrupt;
}

static protected function EventListenerReturn CovertAction_ActionSelectedOverride(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_CovertAction Action;
	local XComLWTuple Tuple;

	Action = XComGameState_CovertAction(EventSource);
	Tuple = XComLWTuple(EventData);

	if (Action == none || Tuple == none || Tuple.Id != 'CovertAction_ActionSelectedOverride') return ELR_NoInterrupt;

	// Stop highlighting the icon
	UIStrategyMapItem(Action.GetVisualizer()).OnMouseOut();

	// Open our custom screen
	class'UIUtilities_Infiltration'.static.UICovertActionsGeoscape(Action.GetReference());

	// Prevent default bahaviour
	Tuple.Data[0].b = true;
	
	// Stop other listeners since we opened a screen already
	return ELR_InterruptListeners;
}

static protected function EventListenerReturn CovertAction_ModifyNarrativeParamTag(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_CovertAction Action;
	local XGParamTag Tag;

	Action = XComGameState_CovertAction(EventSource);
	Tag = XGParamTag(EventData);
	
	if (Action == none || Tag == none) return ELR_NoInterrupt;

	// There is probably a nicer way to this check...
	if (Action.GetMyTemplate().Rewards[0] == 'ActionReward_P2DarkEvent')
	{
		Tag.StrValue4 = GetDarkEventString(Action);
	}

	return ELR_NoInterrupt;
}

static protected function string GetDarkEventString(XComGameState_CovertAction Action)
{
	local XComGameState_Reward RewardState;
	local XComGameState_DarkEvent DarkEventState;

	RewardState = XComGameState_Reward(`XCOMHISTORY.GetGameStateForObjectID(Action.RewardRefs[0].ObjectID));
	DarkEventState = XComGameState_DarkEvent(`XCOMHISTORY.GetGameStateForObjectID(RewardState.RewardObjectReference.ObjectID));

	if (DarkEventState == none)
	{
		return "<Missing DE>";
	}

	return DarkEventState.GetMyTemplate().DisplayName;
}

static protected function EventListenerReturn OnGeoscapeEntry(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_CovertInfiltrationInfo Info;
	local XComGameState NewGameState;
	local UIScreenStack ScreenStack;

	Info = class'XComGameState_CovertInfiltrationInfo'.static.GetInfo();
	ScreenStack = `SCREENSTACK;

	if (Info.bPopupNewActionOnGeoscapeEntrance)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CI: show new actions avaliable popup");
		
		// Turn off the flag
		Info = XComGameState_CovertInfiltrationInfo(NewGameState.ModifyStateObject(class'XComGameState_CovertInfiltrationInfo', Info.ObjectID));
		Info.bPopupNewActionOnGeoscapeEntrance = false;

		// Check that UICovertActionsGeoscape isn't open already or we aren't queued to open it (give preference to clicks from event queue)
		if (!ScreenStack.HasInstanceOf(class'UICovertActionsGeoscape') && !class'UIMapToCovertActionsForcer'.static.IsQueued())
		{
			class'UIUtilities_Infiltration'.static.InfiltrationActionAvaliable(, NewGameState);
		}

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}

	return ELR_NoInterrupt;
}

static protected function EventListenerReturn CovertActionCompleted(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_MissionSiteInfiltration MissionState;
	local XComGameState_CovertAction CovertAction;
	local XComHQPresentationLayer HQPres;

	CovertAction = XComGameState_CovertAction(EventSource);

	if (CovertAction == none)
	{
		return ELR_NoInterrupt;
	}

	if (class'X2Helper_Infiltration'.static.IsInfiltrationAction(CovertAction))
	{
		foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_MissionSiteInfiltration', MissionState)
		{
			if (MissionState.CorrespondingActionRef == CovertAction.GetReference())
			{
				HQPres = `HQPRES;
				HQPres.NotifyBanner(default.strInfiltrationReady, MissionState.GetUIButtonIcon(), MissionState.GetMissionObjectiveText(), default.strCanWaitForBonusOrLaunch, eUIState_Good);
				HQPres.PlayUISound(eSUISound_SoldierPromotion);

				if (`GAME.GetGeoscape().IsScanning())
				{
					`HQPRES.StrategyMap2D.ToggleScan();
				}

				break;
			}
		}
	}
	
	return ELR_NoInterrupt;
}

///////////////////
/// Avenger HUD ///
///////////////////

static function CHEventListenerTemplate CreateAvengerHUDListeners()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'Infiltration_UI_AvengerHUD');
	Template.AddCHEvent('UIAvengerShortcuts_ShowCQResistanceOrders', ShortcutsResistanceButtonVisible, ELD_Immediate);
	Template.AddCHEvent('UpdateResources', UpdateResources, ELD_Immediate);
	Template.RegisterInStrategy = true;

	return Template;
}

static protected function EventListenerReturn ShortcutsResistanceButtonVisible(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none || Tuple.Id != 'UIAvengerShortcuts_ShowCQResistanceOrders') return ELR_NoInterrupt;

	// Only when the Ring is built
	Tuple.Data[0].b = `XCOMHQ.GetFacilityByName('ResistanceRing') != none;
	
	return ELR_NoInterrupt;
}

static function EventListenerReturn UpdateResources(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local UIAvengerHUD AvengerHUD;
	local UIScreenStack ScreenStack;

	local UIScreen CurrentScreen;
	local UICovertActionsGeoscape CovertActions;

	AvengerHUD = `HQPRES.m_kAvengerHUD;
	ScreenStack = AvengerHUD.Movie.Pres.ScreenStack;

	CurrentScreen = ScreenStack.GetCurrentScreen();
	CovertActions = UICovertActionsGeoscape(ScreenStack.GetFirstInstanceOf(class'UICovertActionsGeoscape'));

	if (CovertActions == none) return ELR_NoInterrupt;

	if (
		CurrentScreen == CovertActions ||
		(CovertActions.SSManager != none && CovertActions.SSManager.ShouldShowResourceBar() && CurrentScreen.IsA(class'UISquadSelect'.Name))
	) {
		// Just do same thing as done for UICovertActions
		AvengerHUD.UpdateSupplies();
		AvengerHUD.UpdateIntel();
		AvengerHUD.UpdateAlienAlloys();
		AvengerHUD.UpdateEleriumCrystals();

		// Resource bar is hidden by default, show it
		AvengerHUD.ShowResources();
	}

	return ELR_NoInterrupt;
}

///////////////////
/// Event Queue ///
///////////////////

static function CHEventListenerTemplate CreateEventQueueListeners()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'Infiltration_UI_EventQueue');
	Template.AddCHEvent('GetCovertActionEvents_Settings', GetCovertActionEvents_Settings, ELD_Immediate); // Relies on CHL #391, will be avaliable in v1.18
	Template.RegisterInStrategy = true;

	return Template;
}

static protected function EventListenerReturn GetCovertActionEvents_Settings(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none || Tuple.Id != 'GetCovertActionEvents_Settings') return ELR_NoInterrupt;

	// Show all of them
	Tuple.Data[0].b = true;
	// Insert it sorted
	Tuple.Data[1].b = true;
	
	return ELR_NoInterrupt;
}

//////////////
/// Armory ///
//////////////

static function CHEventListenerTemplate CreateArmoryListeners()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'Infiltration_UI_Armory');
	Template.AddCHEvent('UIArmory_WeaponUpgrade_SlotsUpdated', WeaponUpgrade_SlotsUpdated, ELD_Immediate);
	Template.AddCHEvent('UIArmory_WeaponUpgrade_NavHelpUpdated', WeaponUpgrade_NavHelpUpdated, ELD_Immediate);
	Template.AddCHEvent('CustomizeStatusStringsSeparate', CustomizeStatusStringsSeparate, ELD_Immediate);
	Template.RegisterInStrategy = true;

	return Template;
}

static protected function EventListenerReturn WeaponUpgrade_SlotsUpdated(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local UIDropWeaponUpgradeButton DropButton;
	local UIArmory_WeaponUpgradeItem Slot;
	local UIList SlotsList;
	local UIPanel Panel;

	if (`ISCONTROLLERACTIVE)
	{
		// We add the button only if using mouse
		return ELR_NoInterrupt;
	}

	SlotsList = UIList(EventData);
	if (SlotsList == none)
	{
		`RedScreen("Recived UIArmory_WeaponUpgrade_SlotsUpdated but data isn't UIList");
		return ELR_NoInterrupt;
	}

	foreach SlotsList.ItemContainer.ChildPanels(Panel)
	{
		Slot = UIArmory_WeaponUpgradeItem(Panel);
		if (Slot == none || Slot.UpgradeTemplate == none || Slot.bIsDisabled) continue;

		DropButton = Slot.Spawn(class'UIDropWeaponUpgradeButton', Slot);
		DropButton.InitDropButton();
	}

	return ELR_NoInterrupt;
}

static protected function EventListenerReturn WeaponUpgrade_NavHelpUpdated(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local UIArmory_WeaponUpgrade Screen;
	local UINavigationHelp NavHelp;

	if (!`ISCONTROLLERACTIVE)
	{
		// We add the indicator only if using controller
		return ELR_NoInterrupt;
	}

	Screen = UIArmory_WeaponUpgrade(EventSource);
	NavHelp = UINavigationHelp(EventData);

	if (NavHelp == none)
	{
		`RedScreen("Recived UIArmory_WeaponUpgrade_NavHelpUpdated but data isn't UINavigationHelp");
		return ELR_NoInterrupt;
	}

	if (Screen == none)
	{
		`RedScreen("Recived UIArmory_WeaponUpgrade_NavHelpUpdated but source isn't UIArmory_WeaponUpgrade");
		return ELR_NoInterrupt;
	}

	if (Screen.ActiveList == Screen.SlotsList)
	{
		NavHelp.AddLeftHelp(class'UIUtilities_Infiltration'.default.strDropUpgrade, class'UIUtilities_Input'.const.ICON_X_SQUARE);
	}

	return ELR_NoInterrupt;
}

static protected function EventListenerReturn CustomizeStatusStringsSeparate(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit UnitState;
	local XComGameState_StaffSlot OccupiedSlot;
	local XComGameState_CovertAction Action;
	local string TimeValue, TimeLabel;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none || Tuple.Id != 'CustomizeStatusStringsSeparate') return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	OccupiedSlot = UnitState.GetStaffSlot();

	if (OccupiedSlot.GetMyTemplateName() == 'InfiltrationStaffSlot')
	{	
		Tuple.Data[0].b = true;
		Tuple.Data[1].s = OccupiedSlot.GetBonusDisplayString();	

		Action = OccupiedSlot.GetCovertAction();

		if (Action != none)
		{
			class'UIUtilities_Text'.static.GetTimeValueAndLabel(Action.GetNumHoursRemaining(), TimeValue, TimeLabel);

			Tuple.Data[2].s = TimeLabel;
			Tuple.Data[3].i = int(TimeValue);
		}
	}

	return ELR_NoInterrupt;
}

////////////////////
/// Squad Select ///
////////////////////

static function CHEventListenerTemplate CreateSquadSelectListeners()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'Infiltration_UI_SquadSelect');
	Template.AddCHEvent('UISquadSelect_NavHelpUpdate', SSNavHelpUpdate, ELD_Immediate);
	Template.RegisterInStrategy = true;

	return Template;
}

static protected function EventListenerReturn SSNavHelpUpdate(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local UINavigationHelp NavHelp;

	if (`ISCONTROLLERACTIVE)
	{
		// We add the button only if using mouse
		return ELR_NoInterrupt;
	}

	NavHelp = UINavigationHelp(EventData);
	NavHelp.AddCenterHelp(
		class'UIUtilities_Infiltration'.default.strStripUpgrades,,
		class'UIUtilities_Infiltration'.static.OnStripWeaponUpgrades,,
		class'UIUtilities_Infiltration'.default.strStripUpgradesTooltip
	);

	return ELR_NoInterrupt;
}

//////////////////////////
/// UI Strategy Policy ///
//////////////////////////

static function CHEventListenerTemplate CreateStrategyPolicyListeners()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'Infiltration_UI_StrategyPolicy');
	Template.AddCHEvent('UIStrategyPolicy_ScreenInit', StrategyPolicyInit, ELD_Immediate);
	Template.AddCHEvent('UIStrategyPolicy_ShowCovertActionsOnClose', StrategyPolicy_ShowCovertActionsOnClose, ELD_Immediate);
	Template.RegisterInStrategy = true;

	return Template;
}

static protected function EventListenerReturn StrategyPolicyInit(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_CovertInfiltrationInfo Info;
	local UIStrategyPolicy StrategyPolicy;
	local XComGameState NewGameState;

	StrategyPolicy = UIStrategyPolicy(EventSource);
	if (StrategyPolicy == none) return ELR_NoInterrupt;

	// Pre-first change - use smooth camera transition instead of instant jump from commander's quaters
	if (StrategyPolicy.Movie.Stack.Screens[1].IsA(class'UIFacility_CIC'.Name))
	{
		StrategyPolicy.bInstantInterp = false;
	}

	// First and main change - redirect the camera. This cannot be done in UISL as there will be a frame of camera jump
	class'UIUtilities_Infiltration'.static.CamRingView(StrategyPolicy.bInstantInterp ? float(0) : `HQINTERPTIME);

	// Second change - allow editing cards if did not assign before. This can be done in UISL but why have so many places?
	if (!StrategyPolicy.bResistanceReport && !class'XComGameState_CovertInfiltrationInfo'.static.GetInfo().bCompletedFirstOrdersAssignment)
	{
		StrategyPolicy.bResistanceReport = true;
	}

	// Last change: set bCompletedFirstOrdersAssignment to true. Cannot be inside previous if block as player may build the ring
	// and then wait until supply drop to assign orders. Can also be in UISL
	if (!class'XComGameState_CovertInfiltrationInfo'.static.GetInfo().bCompletedFirstOrdersAssignment)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CI: Completing first order assignment");
		
		Info = class'XComGameState_CovertInfiltrationInfo'.static.GetInfo();
		Info = XComGameState_CovertInfiltrationInfo(NewGameState.ModifyStateObject(class'XComGameState_CovertInfiltrationInfo', Info.ObjectID));
		Info.bCompletedFirstOrdersAssignment = true;
		
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
}

static protected function EventListenerReturn StrategyPolicy_ShowCovertActionsOnClose(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none || Tuple.Id != 'UIStrategyPolicy_ShowCovertActionsOnClose') return ELR_NoInterrupt;

	// Never show actions popup after UIStrategyPolicy
	Tuple.Data[0].b = false;
	
	return ELR_NoInterrupt;
}