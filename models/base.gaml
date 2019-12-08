/*
 * ID2209 Distributed Artificial Intelligence and Intelligent Agents
 * Assignment 1
 * @author: Sumit Patidar <patidar@kth.se>, Utkarsh Kunwar <utkarshk@kth.se>
 *
 */
model base

global {
	float worldDimension <- 100 #m;
	geometry worldShape <- square(worldDimension);
	float step <- 1 #s;

	// Globals for people.
	float max_hunger <- 1.0;
	float max_thirst <- 1.0;
	float hunger_consum <- 0.00001;
	float thirst_consum <- 0.00001;
	float move_speed <- 0.005;
	float dance_speed <- 0.01;
	float building_interaction_distance <- 2.0;
	float guest_interaction_distance <- building_interaction_distance * 5;
	int number_of_guests <- 10;

	// Globals for buildings.
	point informationCentrePoint <- {worldDimension / 2.0, worldDimension / 2.0};
	point exitPoint <- {worldDimension, worldDimension / 2.0};

	init {
		seed <- #pi / 5; // Looked good.
		create FestivalGuest number: number_of_guests;
		create InformationCentre number: 1 with: (name: "InformationCentre", location: informationCentrePoint);
		create ExitGate number: 1 with: (name: "ExitGate", location: exitPoint);
	}

	// Pause after some cycles.
	int max_cycles <- 300000;

	reflex stop when: cycle = max_cycles {
		write "Paused.";
		do pause;
	}

}

// General guest.
species FestivalGuest skills: [moving, fipa] {
// Display icon of the person.
	image_file my_icon <- image_file("../includes/data/dance.png");
	float icon_size <- 1 #m;

	/*
     * Icon statuses to avoid changing icon at every step and decrease
     * rendering overhead.
     * 0 : Dancing
     * 1 : Hungry
     * 2 : Thirsty
     * 3 : Bad
     * 4 : Bored
     */
	int icon_status <- 0;

	aspect icon {
		draw my_icon size: 7 * icon_size;
	}

	float max_boredom <- 1.0;
	float boredom_consum <- 0.00001;

	// Hunger and thirst updates.
	float hunger <- rnd(max_hunger) update: hunger + hunger_consum max: max_hunger;
	float thirst <- rnd(max_thirst) update: thirst + thirst_consum max: max_thirst;
	float boredom <- 0.5;
	point targetPoint <- nil;

	// State variables.
	bool hungry <- false;
	bool thirsty <- false;
	bool moving <- false;
	bool bored <- false;
	int boredom_count <- 0;
	int max_boredom_count <- 3;
	bool at_info <- false;
	bool at_store <- false;
	bool bad <- false;
	bool near_bad <- false;
	point bad_location <- nil;
	FestivalGuest bad_agent <- nil;
	bool leave <- false;
	list<point> foodPoints <- nil;
	point foodPoint <- nil;
	list<point> drinksPoints <- nil;
	point drinksPoint <- nil;
	point random_point <- nil;
	float distance_travelled <- 0.0;
	float wallet <- rnd(0.0, 500.0);

	// Caluclates the distance travelled by the person.
	reflex calculateDistance when: moving {
		distance_travelled <- distance_travelled + move_speed * step;
	}

	// Check if hungry or not. Change icon accordingly. Don't change priority if already doing something.
	reflex isHungry when: !(thirsty or moving) {
		if hunger = 1.0 {
			hungry <- true;
			if icon_status != 1 {
				my_icon <- image_file("../includes/data/hungry.png");
				icon_status <- 1;
			}

		} else {
			hungry <- false;
			if icon_status != 0 {
				my_icon <- image_file("../includes/data/dance.png");
				icon_status <- 0;
			}

		}

	}

	// Check if thirsty or not. Change icon accordingly. Don't change priority if already doing something.
	reflex isThirsty when: !(hungry or moving) {
		if thirst = 1.0 {
			thirsty <- true;
			if icon_status != 2 {
				my_icon <- image_file("../includes/data/thirsty.png");
				icon_status <- 2;
			}

		} else {
			thirsty <- false;
			if icon_status != 0 {
				my_icon <- image_file("../includes/data/dance.png");
				icon_status <- 0;
			}

		}

	}

	// Updates boredom values.
	reflex updateBoredom {
		if boredom >= 1.0 {
			boredom <- 1.0;
		} else if boredom <= 0.0 {
			boredom <- 0.0;
		} else {
			boredom <- boredom + boredom_consum;
		}

	}

	// Check if bored or not. Change icon accordingly. Don't change priority if already doing something.
	reflex isBored when: !(hungry or thirsty or moving) {
		if boredom >= 1.0 {
			bored <- true;
			if icon_status != 4 {
				my_icon <- image_file("../includes/data/bored.png");
				icon_status <- 4;
			}

		} else {
			bored <- false;
			if icon_status != 0 {
				my_icon <- image_file("../includes/data/dance.png");
				icon_status <- 0;
			}

		}

	}

	// Dance.
	reflex dance when: targetPoint = nil and !(hungry or thirsty) {
		do wander speed: dance_speed * ((bad) ? 2 : 1) bounds: square(0.5 #m);
		moving <- false;

		// Check if dancing with someone. If not then you get bored.
		list<FestivalGuest> neighbours <- (FestivalGuest at_distance guest_interaction_distance);
		if length(neighbours) = 0 {
			boredom_consum <- 0.00001;
		} else {
			loop neighbour over: neighbours {
				ask neighbour {
					if self.targetPoint = nil and !(self.hungry or self.thirsty) {
						myself.boredom_consum <- -0.000008;
						break;
					}

				}

			}

		}

	}

	// Move to a given point.
	reflex moveToTarget when: targetPoint != nil {
		do goto target: targetPoint speed: move_speed * ((bad) ? 2 : 1);
		moving <- true;
	}

	// Go to information centre if hungry or thirsty.
	reflex goToInformationCentre when: (hungry or thirsty) and !at_info {
	/*
    	 * If already remember the point you've been to then go to there
    	 * directly instead of going to the information centre. Since,
    	 * you've already been to the information centre, the state can
    	 * be skipped/extended.
    	 */
		if hungry and foodPoint != nil {
			foodPoint <- any(foodPoints);
			targetPoint <- foodPoint;
			at_info <- true;
		} else if thirsty and drinksPoint != nil {
			drinksPoint <- any(drinksPoints);
			targetPoint <- drinksPoint;
			at_info <- true;
		} else {
			bool asked <- false;
			/*
    		 * Ask from a list of neighbours around you and if they know the location
    		 * then go to that location instead of going to the information centre.
    		 */
			list<FestivalGuest> neighbours <- FestivalGuest at_distance (guest_interaction_distance);
			loop neighbour over: neighbours {
				ask neighbour {
					if myself.hungry and self.foodPoint != nil {
						myself.foodPoints <- self.foodPoints;
						myself.foodPoint <- any(myself.foodPoints);
						myself.targetPoint <- myself.foodPoint;
						myself.at_info <- true;
						asked <- true;
						write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + ") Got food point from neighbour (" + string(self.name) + ")";
						break;
					} else if myself.thirsty and self.drinksPoint != nil {
						myself.drinksPoints <- self.drinksPoints;
						myself.drinksPoint <- any(myself.drinksPoints);
						myself.targetPoint <- myself.drinksPoint;
						myself.at_info <- true;
						asked <- true;
						write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + "Got drinks point from neighbour (" + string(self.name) + ")";
						break;
					}

				}

			}

			if !asked {
				targetPoint <- informationCentrePoint;
			}

		}

	}

	// Check if at information centre.
	reflex atInformationCentre when: (hungry or thirsty) and !at_info and location distance_to (informationCentrePoint) < building_interaction_distance and !at_store {
		at_info <- true;
		moving <- false;
		write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") At Information Centre";
	}

	// Get store location from information centre.
	reflex getStoreLocation when: (hungry or thirsty) and at_info and !at_store {
		ask InformationCentre {
		// Ask for food/drink when hungry/thirsty and don't know the location.
			if myself.hungry and myself.foodPoint = nil {
				myself.foodPoints <- self.foodPoints;
				myself.foodPoint <- any(myself.foodPoints);
				myself.targetPoint <- myself.foodPoint;
				write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + ") Got Food Point";
			}

			if myself.thirsty and myself.drinksPoint = nil {
				myself.drinksPoints <- self.drinksPoints;
				myself.drinksPoint <- any(myself.drinksPoints);
				myself.targetPoint <- myself.drinksPoint;
				write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + ") Got Drinks Point";
			}

		}

	}

	// Check if at store and get food and replenish health at the food store.
	reflex atFoodStoreLocation when: hungry and at_info and foodPoint != nil and location distance_to (foodPoint) < building_interaction_distance {
		at_store <- true;
		at_info <- false;
		moving <- false;
		hunger <- 0.0;
		hungry <- false;
		thirst <- thirst / 1.5; // When you're full you feel like drinking less.
		thirsty <- false;
		boredom <- boredom / 1.2;
		bored <- false;
		random_point <- {rnd(worldDimension), rnd(worldDimension)};
		targetPoint <- random_point;
		write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") At Food Point";
	}

	// Check if at store and get drinks and replenish health at the drinks store.
	reflex atDrinksStoreLocation when: thirsty and at_info and drinksPoint != nil and location distance_to (drinksPoint) < building_interaction_distance {
		at_store <- true;
		at_info <- false;
		moving <- false;
		thirst <- 0.0;
		thirsty <- false;
		hunger <- hunger / 2.0; // When you drink a lot you feel like eating less.
		hungry <- false;
		boredom <- boredom / 1.2;
		bored <- false;
		random_point <- {rnd(worldDimension), rnd(worldDimension)};
		targetPoint <- random_point;
		write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") At Drinks Point";
	}

	// Check if at random point.
	reflex atRandomPoint when: at_store and random_point != nil and location distance_to (random_point) < building_interaction_distance {
		at_store <- false;
		at_info <- false;
		moving <- false;
		random_point <- nil;
		targetPoint <- nil;
		write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") At Random Point";
	}

	// Become bad with some probability after some time.
	reflex comeToTheDarkSide when: !bad and mod(cycle, 1000) = 0 and length(FestivalGuest at_distance (guest_interaction_distance)) > 0 and !moving and targetPoint = nil {
		bad <- flip(1.0 / number_of_guests);
		if bad {
			write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") has come to the dark side.";
		}

	}

	// If you're bad, all normal guests priorities are removed.
	reflex amIBad when: bad {
		if icon_status != 3 {
			my_icon <- image_file("../includes/data/bad.png");
			icon_status <- 3;
		}

		hunger <- 0.0;
		hungry <- false;
		thirst <- 0.0;
		thirsty <- false;
		moving <- false;
		near_bad <- false;
		if leave {
			targetPoint <- exitPoint;
		} else {
			targetPoint <- nil;
		}

	}

	// Go and complain to the information centre if you're near a bad person.
	reflex nearBadPerson when: !bad and !(hungry or thirsty or moving) {
		list<FestivalGuest> neighbours <- FestivalGuest at_distance (guest_interaction_distance);
		loop neighbour over: neighbours {
			ask neighbour {
				if self.bad and !myself.bad {
					myself.near_bad <- true;
					myself.targetPoint <- informationCentrePoint;
					//myself.bad_location <- self.location;
					myself.bad_agent <- self;
					break;
				}

			}

		}

	}

	// Dance with the closest non-bad person when bored. If bored for too long then leave.
	reflex onBored when: bored {
		if boredom_count >= max_boredom_count {
			leave <- true;
			targetPoint <- exitPoint;
		} else {
			list<FestivalGuest> neighbours <- FestivalGuest at_distance (5 * guest_interaction_distance);
			if length(neighbours) = 0 {
				boredom_count <- boredom_count + 1;
			}

			loop neighbour over: neighbours {
				ask neighbour {
					if !self.bad and self.targetPoint = nil and !(self.hungry or self.thirsty) {
						myself.random_point <- self.location + {rnd(guest_interaction_distance), rnd(guest_interaction_distance)};
						if float(myself.random_point.x) > worldDimension {
							myself.random_point <- {worldDimension, myself.random_point.y};
						}

						if float(myself.random_point.y) > worldDimension {
							myself.random_point <- {myself.random_point.x, worldDimension};
						}

						if float(myself.random_point.x) < 0.0 {
							myself.random_point <- {0.0, myself.random_point.y};
						}

						if float(myself.random_point.y) < 0.0 {
							myself.random_point <- {myself.random_point.x, 0.0};
						}

						myself.targetPoint <- myself.random_point;
						myself.at_store <- true;
						myself.boredom <- 0.8;
						myself.bored <- false;
						myself.boredom_count <- myself.boredom_count + 1;
						write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + ") going to dance with (" + string(self.name) + ")";
						break;
					} else if self.bad {
						boredom_count <- boredom_count + 1;
					}

				}

			}

		}

	}

	// Leave the place when at exit.
	reflex leaveFestival when: leave and location distance_to (exitPoint) < building_interaction_distance {
		write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") has left the event" + ((bored) ? " because he is bored." : ".");
		do die;
	}

	// read inform msgs from security guard
	list<string> leave_msgs <- ['Get out', 'GET OUT YOU F***R'];

	reflex receive_inform_msgs when: !empty(informs) {
		message inf <- informs[0];
		switch inf.contents[0] {
			match leave_msgs[0] {
			// bribe if you have some money
				if (wallet > 0) {
					write "Cycle (" + string(cycle) + ") Agent (" + (self.name) + ") try to bribe " + wallet + " to " + agent(inf.sender).name + ")";
					do start_conversation with: [to::list(inf.sender), protocol::'fipa-contract-net', performative::'request', contents::['BRIBE', wallet]];
				} else {
				// fool guard and change location
					do start_conversation with: [to::list(inf.sender), protocol::'fipa-contract-net', performative::'request', contents::['OK']];
				}

			}

			match leave_msgs[1] {
			// bribe if you have some money
				if (wallet > 0) {
					write "Cycle (" + string(cycle) + ") Agent (" + (self.name) + ") try to bribe " + wallet + " to " + agent(inf.sender).name + ")";
					do start_conversation with: [to::list(inf.sender), protocol::'fipa-contract-net', performative::'request', contents::['BRIBE', wallet]];
				} else {
				// sincerely go out
					do start_conversation with: [to::list(inf.sender), protocol::'fipa-contract-net', performative::'request', contents::['OK']];
					leave <- true;
					targetPoint <- exitPoint;
				}

			}

		}

	}

	// read agree msg
	reflex receive_agree_msgs when: !empty(agrees) {
	// change location or turn into good guy
		message msg <- agrees[0];
		wallet <- wallet - int(msg.contents[1]);
	}

	// read refused msg
	reflex receive_refuse_msgs when: !empty(refuses) {
		leave <- true;
		targetPoint <- exitPoint;
	}

}

//------------------------------------------------------Security Guard Begins------------------------------------------------------
// Security Guard
species SecurityGuard skills: [moving, fipa] {
// Display icon of the information centre.
	image_file my_icon <- image_file("../includes/data/security.png");
	float icon_size <- 1 #m;

	aspect icon {
		draw my_icon size: 10 * icon_size;
	}

	bool hunting <- false;
	bool eliminated <- false;
	bool isCorrupt <- false;
	bool isStrict <- false;
	float corruptness <- rnd(0.0, 1.0);
	float strictness <- rnd(0.0, 1.0);
	float wallet <- 0.0;
	point securityGuardPoint <- location;
	point targetPoint <- nil;
	FestivalGuest bad_agent <- nil;
	list<string> leave_msgs <- ['Get out', 'GET OUT YOU F***R'];
	bool reached_bad_agent <- false;
	// Move to a given point.
	reflex moveToTarget when: targetPoint != nil {
		do goto target: targetPoint speed: move_speed * 2;
	}

	// Update wallet money for English Auction
	reflex recive_request_from_evil_guy when: !empty(requests) and reached_bad_agent {
		message req <- requests[0];
		if (req.contents[0] = 'OK') {
		// evil guy will leave or change location
			if (isStrict) {
			// escort the evil guy 
				eliminated <- true;
				targetPoint <- exitPoint;
			} else {
			// assume he will go out himself 
				eliminated <- true;
			}

		} else if (req.contents[0] = 'BRIBE') {
		// security guard takes bribe if he is corrupt
			if (isCorrupt) {
			// take bribe
				write "Cycle (" + string(cycle) + ") Agent (" + (self.name) + ") takes " + string(req.contents[1]) + " bribe from (" + agent(req.sender).name + ")";
				do agree with: [message:: req, contents::['Enjoy', req.contents[1]]];
				wallet <- wallet + int(req.contents[1]);
				eliminated <- true;
			} else {
				write "Cycle (" + string(cycle) + ") Agent (" + (self.name) + ") refuse to take " + string(req.contents[1]) + " bribe from (" + agent(req.sender).name + ")";
				do refuse with: [message:: req, contents::[leave_msgs[1]]];
				eliminated <- true;
			}

		}

		hunting <- false;

		// Remove the guy from list (even if he wasn't removed because he could not be found).
		ask InformationCentre {
			remove first(self.badPeopleLocations) from: self.badPeopleLocations;
			write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + ") Removed trouble maker (" + string(myself.bad_agent.name) + ")";
			write "Cycle (" + string(cycle) + ") Agent (" + string(self.name) + ") " + string(length(self.badPeopleLocations)) + " complaint(s).";
		}

	}
	// Escort the suspect out of the venue.
	reflex nearTarget when: hunting and location distance_to (targetPoint) < building_interaction_distance and !reached_bad_agent {
		reached_bad_agent <- true;
		if (!isStrict) {
			do start_conversation with: [to::list(bad_agent), protocol::'fipa-contract-net', performative::'inform', contents::[leave_msgs[0], exitPoint]];
		} else {
			do start_conversation with: [to::list(bad_agent), protocol::'fipa-contract-net', performative::'inform', contents::[leave_msgs[1], exitPoint]];
		}

		//		list<FestivalGuest> suspects <- FestivalGuest at_distance (guest_interaction_distance);
		//		loop suspect over: suspects {
		//			ask suspect {
		//				if self.bad {
		//					self.leave <- true;
		//					self.targetPoint <- exitPoint;
		//					myself.targetPoint <- exitPoint;
		//					//myself.badName <- self.name;
		//					myself.eliminated <- true;
		//					break;
		//				}
		//
		//			}
		//
		//		}
		//		hunting <- false;
		//
		//		// Remove the guy from list (even if he wasn't removed because he could not be found).
		//		ask InformationCentre {
		//			remove first(self.badPeopleLocations) from: self.badPeopleLocations;
		//			write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + ") Removed trouble maker (" + string(myself.bad_agent.name) + ")";
		//			write "Cycle (" + string(cycle) + ") Agent (" + string(self.name) + ") " + string(length(self.badPeopleLocations)) + " complaint(s).";
		//		}
		//
		//		if !eliminated {
		//			write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") Unable to find bad person.";
		//			targetPoint <- securityGuardPoint;
		//		}

	}

	// Change state when at secturity post.
	reflex atSecurityPost when: location distance_to (securityGuardPoint) < building_interaction_distance {
		hunting <- false;
		eliminated <- false;
	}

	// Change state when at exit gate.
	reflex atExitGate when: eliminated and location distance_to (exitPoint) < building_interaction_distance {
		targetPoint <- securityGuardPoint;
		hunting <- false;
	}

}

//------------------------------------------------------Security Guard Ends------------------------------------------------------
//------------------------------------------------------Information Centre Begins------------------------------------------------------
// Information Centre
species InformationCentre {
// Display icon of the information centre.
	image_file my_icon <- image_file("../includes/data/information_centre.png");
	float icon_size <- 1 #m;

	aspect icon {
		draw my_icon size: 10 * icon_size;
	}

	// Parameters for stores.
	int nFoodPoints <- 2;
	int nDrinksPoints <- 2;

	// State variables.
	list<point> foodPoints <- [];
	list<point> drinksPoints <- [];
	list<point> badPeopleLocations <- [];
	list<FestivalGuest> badPeoples <- [];
	point securityGuardPoint <- informationCentrePoint + {-10.0, 0.0};

	init {
	// Randomised locations.
		int i <- 1;
		loop i from: 1 to: nFoodPoints {
			point foodPoint <- {rnd(worldDimension), rnd(worldDimension)};
			foodPoints <+ foodPoint;
			point drinksPoint <- {rnd(worldDimension), rnd(worldDimension)};
			drinksPoints <+ drinksPoint;
			create FoodShop number: 1 with: (location: foodPoint);
			create DrinksShop number: 1 with: (location: drinksPoint);
		}

		// Spawn security guard.
		create SecurityGuard number: 1 with: (location: securityGuardPoint);
	}

	// Gets the location of the baddies from the guest who has come to complain.
	reflex guestComplaint {
		list<FestivalGuest> guests <- FestivalGuest at_distance (building_interaction_distance);
		loop guest over: guests {
			ask guest {
				if self.near_bad {
					myself.badPeopleLocations <+ self.bad_location;
					myself.badPeoples <+ self.bad_agent;
					self.near_bad <- false;
					self.bad_location <- nil;
					self.random_point <- {rnd(worldDimension), rnd(worldDimension)};
					self.targetPoint <- self.random_point;
					self.at_store <- true; // To reset the state of the person. No significance to reporting of bad person.
					write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + ") Bad Guy Reported by (" + string(self.name) + ")";
					write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + ") " + string(length(myself.badPeopleLocations)) + " complaint(s).";
				}

			}

		}

	}

	// Sends message to security guard about one of the bad people locations.
	reflex informSecurity when: length(badPeopleLocations) > 0 {
		ask SecurityGuard {
			if !self.hunting {
				self.targetPoint <- myself.badPeopleLocations[0];
				self.bad_agent <- myself.badPeoples[0];
				self.hunting <- true;
			}

		}

	} }
	//------------------------------------------------------Information Centre Ends------------------------------------------------------
// Food Shop.
species FoodShop schedules: [] frequency: 0 {
// Display icon of the food shop.
	image_file my_icon <- image_file("../includes/data/food.png");
	float icon_size <- 1 #m;

	aspect icon {
		draw my_icon size: 10 * icon_size;
	}

}

// Drinks Shop.
species DrinksShop schedules: [] frequency: 0 {
// Display icon of the drinks shop.
	image_file my_icon <- image_file("../includes/data/drinks.png");
	float icon_size <- 1 #m;

	aspect icon {
		draw my_icon size: 10 * icon_size;
	}

}

// Drinks Shop.
species ExitGate schedules: [] frequency: 0 {
// Display icon of the drinks shop.
	image_file my_icon <- image_file("../includes/data/exit.png");
	float icon_size <- 1 #m;

	aspect icon {
		draw my_icon size: 10 * icon_size;
	}

}

// Experiment.
experiment festival type: gui {
	output {
	// Display map.
		display myDisplay type: opengl {
			species FestivalGuest aspect: icon;
			species InformationCentre aspect: icon refresh: false;
			species FoodShop aspect: icon refresh: false;
			species DrinksShop aspect: icon refresh: false;
			species SecurityGuard aspect: icon;
			species ExitGate aspect: icon refresh: false;
		}

		inspect "distance inspector" value: FestivalGuest attributes: ["boredom", "wallet"];
		inspect "wallet money inspector" value: SecurityGuard attributes: ["wallet"];
	}

}
