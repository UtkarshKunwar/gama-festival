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
	float move_speed <- 0.01;
	float dance_speed <- 0.01;
	float building_interaction_distance <- 2.0;
	float guest_interaction_distance <- building_interaction_distance * 5;
	int number_of_guests <- 10;
	int number_of_journalists <- 3;
	int number_of_evil_guys <- 3;

	// Globals for buildings.
	point informationCentrePoint <- {worldDimension / 2.0, worldDimension / 2.0};
	point exitPoint <- {worldDimension, worldDimension / 2.0};

	//globals for Stage
	int nb_stage <- 3;
	list<point>
	stages_locs <- [{worldDimension / 4, worldDimension / 4}, {worldDimension / 4, worldDimension * (3 / 4)}, {worldDimension * (3 / 4), worldDimension * (3 / 4)}, {worldDimension * (3 / 4), worldDimension / 4}];
	list<string> roles <- ['band', 'singer', 'dancer'];

	init {
		seed <- #pi / 5; // Looked good.
		create FestivalGuest number: number_of_guests;
		create InformationCentre number: 1 with: (name: "InformationCentre", location: informationCentrePoint);
		create Journalist number: number_of_journalists;
		create EvilGuest number: number_of_evil_guys;
		create ExitGate number: 1 with: (name: "ExitGate", location: exitPoint);

		// Randomised locations for stages.
		int i <- 0;
		bool decent_loc <- false;
		loop i from: 0 to: nb_stage - 1 {
		//			point stage_point <- {rnd(worldDimension), rnd(worldDimension)};
		//			stages_locs <+ stage_point;
			create Stage number: 1 with: (location: stages_locs[i], role: roles[i]);
		} }

	int max_cycles <- 300000;

	reflex stop when: cycle = max_cycles {
		write "Paused.";
		do pause;
	} }

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

	// Personality
	bool party <- flip(0.5); // if not party it is implied that the guest is chill 
	bool friendly <- flip(0.3);
	float max_boredom <- 1.0;
	float boredom_consum <- friendly ? 0.00002 : 0.00001;

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
	bool near_bad <- false;
	point bad_location <- nil;
	EvilGuest bad_agent <- nil;
	bool leave <- false;
	list<point> foodPoints <- nil;
	point foodPoint <- nil;
	list<point> drinksPoints <- nil;
	point drinksPoint <- nil;
	point random_point <- nil;
	float distance_travelled <- 0.0;
	float wallet <- rnd(0.0, 500.0);
	bool being_interviewed <- false;
	bool want_to_be_interviewed <- friendly ? flip(0.3) : flip(0.7);

	// Generosity
	float max_generosity <- 1.0;
	float generosity_consum <- 0.00005;
	float generosity <- rnd(max_generosity) update: generosity + generosity_consum max: max_generosity;
	bool generous <- false;
	bool want_drink <- friendly ? flip(0.3) : flip(0.7);
	bool offered_drink <- false;
	bool has_drink <- false;
	point drinkee_point <- nil;
	FestivalGuest offerer <- nil;
	EvilGuest offerer_e <- nil;
	bool bad <- false;

	// Stage variables
	list<float> my_preferences <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)]; //1.Lightshow 2.Speakers 3.Band 4.Seats 5.Food 6.Popularity
	list<point> stage_locs <- nil;
	list<float> stage_utility <- nil;
	list<string> stages <- nil;
	point best_stage_loc <- nil;
	agent best_stage <- nil;
	float best_utility <- 0.0;
	list<string> acts <- nil;
	string best_act <- nil;
	bool all_stage_evaluated <- false;
	float max_utility <- 0.0;
	int stage_count <- 0;

	// Caluclates the distance travelled by the person.
	reflex calculateDistance when: moving {
		distance_travelled <- distance_travelled + move_speed * step;
	}

	// Check if hungry or not. Change icon accordingly. Don't change priority if already doing something.
	reflex isHungry when: !(thirsty or moving) {
		if hunger = 1.0 {
			hungry <- true;
		} else {
			hungry <- false;
		}

	}

	// Check if thirsty or not. Change icon accordingly. Don't change priority if already doing something.
	reflex isThirsty when: !(hungry or moving) {
		if thirst = 1.0 {
			thirsty <- true;
		} else {
			thirsty <- false;
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

	reflex isBeingInterviewed when: being_interviewed and mod(cycle, 10000) = 0 {
		being_interviewed <- false;
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

	// Check if generous or not. Don't change priority if already doing something.
	reflex isGenerous when: !(hungry or thirsty or moving or bored) {
		if generosity >= 1.0 {
			generous <- true;
		} else {
			generous <- false;
		}

	}

	// Dance.
	reflex dance when: targetPoint = nil and !(hungry or thirsty) {
		do wander speed: party ? dance_speed * 3 : dance_speed bounds: square(0.5 #m);
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
		do goto target: targetPoint speed: move_speed;
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
						break;
					} else if myself.thirsty and self.drinksPoint != nil {
						myself.drinksPoints <- self.drinksPoints;
						myself.drinksPoint <- any(myself.drinksPoints);
						myself.targetPoint <- myself.drinksPoint;
						myself.at_info <- true;
						asked <- true;
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
	}

	// Get store location from information centre.
	reflex getStoreLocation when: (hungry or thirsty) and at_info and !at_store {
		ask InformationCentre {
		// Ask for food/drink when hungry/thirsty and don't know the location.
			if myself.hungry and myself.foodPoint = nil {
				myself.foodPoints <- self.foodPoints;
				myself.foodPoint <- any(myself.foodPoints);
				myself.targetPoint <- myself.foodPoint;
			}

			if myself.thirsty and myself.drinksPoint = nil {
				myself.drinksPoints <- self.drinksPoints;
				myself.drinksPoint <- any(myself.drinksPoints);
				myself.targetPoint <- myself.drinksPoint;
			}

		}

	}

	// Check if at random point.
	reflex atRandomPoint when: at_store and random_point != nil and location distance_to (random_point) < building_interaction_distance {
		at_store <- false;
		at_info <- false;
		moving <- false;
		random_point <- nil;
		targetPoint <- nil;
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
		//write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") At Food Point";
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
		want_to_be_interviewed <- flip(0.5);
		if drinkee_point != nil {
			has_drink <- true;
			random_point <- drinkee_point;
			targetPoint <- drinkee_point;
		} else {
			random_point <- {rnd(worldDimension), rnd(worldDimension)};
			targetPoint <- random_point;
		}
		//write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") At Drinks Point";
	}

	// Go and complain to the information centre if you're near a bad person.
	reflex nearBadPerson when: !(hungry or thirsty or moving) {
		list<EvilGuest> neighbours <- EvilGuest at_distance (guest_interaction_distance);
		loop neighbour over: neighbours {
			ask neighbour {
				if self.bad {
					myself.near_bad <- true;
					myself.targetPoint <- informationCentrePoint;
					myself.bad_location <- self.location; // not needed
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
					if self.targetPoint = nil and !(self.hungry or self.thirsty) and (!myself.friendly or flip(0.5)) {
						myself.random_point <- self.location + {rnd(guest_interaction_distance), rnd(guest_interaction_distance)};
						if myself.random_point.x > worldDimension {
							myself.random_point <- {worldDimension, myself.random_point.y};
						}

						if myself.random_point.y > worldDimension {
							myself.random_point <- {myself.random_point.x, worldDimension};
						}

						if myself.random_point.x < 0.0 {
							myself.random_point <- {0.0, myself.random_point.y};
						}

						if myself.random_point.y < 0.0 {
							myself.random_point <- {myself.random_point.x, 0.0};
						}

						myself.targetPoint <- myself.random_point;
						myself.at_store <- true;
						myself.boredom <- 0.8;
						myself.bored <- false;
						myself.boredom_count <- myself.boredom_count + 1;
						write "Cycle (" + string(cycle) + ") Agent (" + myself.name + ") going to dance with (" + self.name + ")";
						break;
					}

				}

			}

		}

	}

	// Leave the place when at exit.
	reflex leaveFestival when: leave and location distance_to (exitPoint) < building_interaction_distance {
		write "Cycle (" + string(cycle) + ") Agent (" + name + ") has left the event" + ((bored) ? " because he is bored." : ".");
		do die;
	}

	// You'll agree for free drinks when thristy.
	reflex wantDrinkFromOthers when: thirst > 0.75 and !want_drink and (!friendly or flip(0.5)) {
		want_drink <- true;
	}

	// Look for drinking buddies when feeling generous.
	reflex findDrinkingBuddies when: !moving and generous and drinkee_point = nil and (!friendly or flip(0.5)) and (length(DrinksShop at_distance (5 * building_interaction_distance))
	!= 0) {
		list<EvilGuest> neighbours <- EvilGuest at_distance (2 * guest_interaction_distance);
		if length(neighbours) = 0 {
			list<FestivalGuest> neighbours <- FestivalGuest at_distance (2 * guest_interaction_distance);
		}

		loop neighbour over: neighbours {
			ask neighbour {
				if !self.moving and !self.bad {
					myself.at_store <- true;
					myself.random_point <- {self.location.x + rnd(building_interaction_distance), self.location.y + rnd(building_interaction_distance)};
					myself.targetPoint <- myself.random_point;
					break;
				}

			}

		}

	}

	// Offer drink when feeling generous.
	reflex offerDrink when: !moving and generous and drinkee_point = nil and (!friendly or flip(0.5)) and (length(DrinksShop at_distance (2 * guest_interaction_distance)) != 0) {
		list<EvilGuest> neighbours <- EvilGuest at_distance (2 * guest_interaction_distance);
		if length(neighbours) = 0 {
			list<FestivalGuest> neighbours <- FestivalGuest at_distance (2 * guest_interaction_distance);
		}

		loop neighbour over: neighbours {
			ask neighbour {
				if !(self.moving or self.offered_drink) and self.want_drink {
					self.thirst <- 0.75;
					self.generosity <- 0.2;
					myself.thirst <- 1.0;
					self.offered_drink <- true;
					self.offerer <- myself;
					myself.generosity <- 0.25;
					myself.drinkee_point <-
					{self.location.x + rnd(-building_interaction_distance, building_interaction_distance), self.location.y + rnd(-building_interaction_distance, building_interaction_distance)};
					write "Cycle (" + string(cycle) + ")" + myself.name + " offered drink to " + self.name;
					break;
				}

			}

		}

	}

	// Receive drink from the offerer.
	reflex receiveDrink when: offered_drink {
		if offerer != nil {
			ask offerer {
				if self.location distance_to (myself.location) < guest_interaction_distance and self.has_drink {
					myself.thirst <- 0.25;
					myself.offered_drink <- false;
					myself.want_drink <- flip(0.2);
					myself.moving <- false;
					self.thirst <- 0.25;
					self.drinkee_point <- nil;
					self.has_drink <- false;
					myself.offerer <- nil;
					myself.at_store <- true;
					self.at_store <- true;
					self.random_point <- {rnd(worldDimension), rnd(worldDimension)};
					self.targetPoint <- self.random_point;
					myself.random_point <- {rnd(worldDimension), rnd(worldDimension)};
					myself.targetPoint <- myself.random_point;
					write "Cycle (" + string(cycle) + ")" + myself.name + " received drink from " + self.name;
				}

			}

		}

		if offerer_e != nil {
			ask offerer_e {
				if !self.bad and self.location distance_to (myself.location) < guest_interaction_distance and self.has_drink {
					myself.thirst <- 0.25;
					myself.offered_drink <- false;
					myself.want_drink <- flip(0.2);
					myself.moving <- false;
					self.thirst <- 0.25;
					self.drinkee_point <- nil;
					self.has_drink <- false;
					myself.offerer_e <- nil;
					myself.at_store <- true;
					self.random_point <- {rnd(worldDimension), rnd(worldDimension)};
					self.targetPoint <- self.random_point;
					myself.random_point <- {rnd(worldDimension), rnd(worldDimension)};
					myself.targetPoint <- myself.random_point;
					write "Cycle (" + string(cycle) + ")" + myself.name + " received drink from " + self.name;
				}

			}

		}

	}

	// Reacting to Stages Invite------------------------
	// Utility function
	float get_utility (list<float> act_attributes) {
	// Add a more complex function for utility with atleast 6 variables
		float
		utility <- act_attributes[0] * my_preferences[0] + act_attributes[1] * my_preferences[1] + act_attributes[2] * my_preferences[2] + act_attributes[3] * my_preferences[3] + act_attributes[4] * my_preferences[4] + act_attributes[5] * my_preferences[5];
		return utility;
	}

	// Read inform msgs from stages.
	reflex receive_inform_messages when: !empty(informs) {
	//write '\n(Time ' + time + '): ' + name + ' receives inform messages.' + informs;
		loop information over: informs {
			if (string(information.contents[0]) = 'Invitation') {
				stage_count <- stage_count + 1;
				// Evaluate utility of the act
				float current_utility <- get_utility(information.contents[1]);
				stage_utility <+ current_utility;
				stage_locs <+ agent(information.sender).location;
				stages <+ agent(information.sender).name;
				acts <+ information.contents[2];
				//write '\t(Time ' + time + '): ' + agent(information.sender).name + ' utility: ' + current_utility;
				// keep track of best stages
				if (current_utility > max_utility) {
					max_utility <- current_utility;
					best_stage_loc <- agent(information.sender).location;
					best_stage <- agent(information.sender);
					best_act <- information.contents[2];
				}

			} else if (string(information.contents[0]) = 'Act ends') {
				stage_utility <- nil;
				stage_locs <- nil;
				max_utility <- 0.0;
				stage_count <- 0;
				all_stage_evaluated <- false;
				at_store <- true;
				random_point <- {rnd(worldDimension), rnd(worldDimension)};
				targetPoint <- random_point;
			}

		}

		// when all stages invitations are considered, go to best one
		if (stage_count = 3) {
			all_stage_evaluated <- true;
			stage_count <- 0;
		}

	}

	// Go to best stage
	reflex gotoBestStage when: all_stage_evaluated {
		do start_conversation with: [to::list(best_stage), protocol::'fipa-contract-net', performative::'inform', contents::['I am coming']];
		targetPoint <- best_stage_loc;
		float dx <- friendly ? rnd(-20.0, 20.0) : rnd(-10.0, 10.0);
		float dy <- friendly ? rnd(32.0, 40.0) : rnd(8.0, 10.0);
		targetPoint <- {targetPoint.x + dx, targetPoint.y + rnd(8, 10)};
		best_utility <- stage_utility[stage_locs index_of (best_stage_loc)];
		write '\t(Time ' + time + '): ' + name + ' choice: ' + best_stage + " with utility " + best_utility;
		all_stage_evaluated <- false;
	}

	// Shy away when near a lot of people.
	reflex shyAway when: !moving and friendly and flip(0.5) and mod(cycle, 10000) = 0 {
		list<EvilGuest> evil_neighbours <- EvilGuest at_distance (3 * guest_interaction_distance);
		list<FestivalGuest> neighbours <- FestivalGuest at_distance (2 * guest_interaction_distance);
		list<Journalist> journalist_neighbours <- Journalist at_distance (5 * guest_interaction_distance);
		int count <- length(neighbours) + length(evil_neighbours) + length(journalist_neighbours);
		int max_count <- int((number_of_evil_guys + number_of_guests + number_of_journalists) / 4);
		if count >= max_count {
			random_point <- {rnd(worldDimension), rnd(worldDimension)};
			targetPoint <- random_point;
			at_store <- true;
			write "Cycle (" + cycle + ") (" + name + ") feeling friendly. Moving to new location.";
		}

	}

}

//----------------------------------------------------Evil Guest begins---------------------------------------------------------
species EvilGuest skills: [moving, fipa] {
// Display icon of the person.
	image_file my_icon <- image_file("../includes/data/bad.png");
	float icon_size <- 1 #m;
	int icon_status <- 0;

	aspect icon {
		draw my_icon size: 7 * icon_size;
	}

	bool thirsty <- false;
	float thirst <- rnd(max_thirst) update: thirst + thirst_consum max: max_thirst;
	float max_boredom <- 1.0;
	float boredom_consum <- 0.00001;
	float boredom <- 0.5;
	point targetPoint <- nil;

	// State variables.
	bool moving <- false;
	bool bored <- false;
	int boredom_count <- 0;
	int max_boredom_count <- 3;
	bool leave <- false;
	point random_point <- nil;
	float distance_travelled <- 0.0;
	float wallet <- rnd(100.0, 500.0);
	bool bad <- false;
	float max_generosity <- 1.0;
	float generosity_consum <- 0.00005;
	float generosity <- rnd(max_generosity) update: generosity + generosity_consum max: max_generosity;
	bool generous <- false;
	bool want_drink <- flip(0.5);
	bool offered_drink <- false;
	bool has_drink <- false;
	point drinkee_point <- nil;
	FestivalGuest offerer <- nil;

	// Stage variables
	list<float> my_preferences <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)]; //1.Lightshow 2.Speakers 3.Band 4.Seats 5.Food 6.Popularity
	list<point> stage_locs <- nil;
	list<float> stage_utility <- nil;
	list<string> stages <- nil;
	point best_stage_loc <- nil;
	agent best_stage <- nil;
	float best_utility <- 0.0;
	list<string> acts <- nil;
	string best_act <- nil;
	bool all_stage_evaluated <- false;
	float max_utility <- 0.0;
	int stage_count <- 0;

	// Caluclates the distance travelled by the person.
	reflex calculateDistance when: moving {
		distance_travelled <- distance_travelled + move_speed * step;
	}

	// Become bad with some probability after some time.
	reflex comeToTheDarkSide when: !bad and mod(cycle, 1000) = 0 and length(FestivalGuest at_distance (guest_interaction_distance)) > 0 and !moving and targetPoint = nil {
		bad <- flip(1.0 / number_of_guests);
		if bad {
			write "Cycle (" + string(cycle) + ") Agent (" + name + ") has come to the dark side.";
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

	// Check if thirsty or not. Change icon accordingly. Don't change priority if already doing something.
	reflex isThirsty when: !moving {
		if thirst = 1.0 {
			thirsty <- true;
		} else {
			thirsty <- false;
		}

	}

	// Check if bored or not. Change icon accordingly. Don't change priority if already doing something.
	reflex isBored when: !moving {
		if boredom >= 1.0 {
			bored <- true;
			if icon_status != 4 {
				my_icon <- image_file("../includes/data/bored.png");
				icon_status <- 4;
			}

		} else {
			bored <- false;
			if icon_status != 0 {
				my_icon <- image_file("../includes/data/bad.png");
				icon_status <- 0;
			}

		}

	}

	// Check if generous or not. Don't change priority if already doing something.
	reflex isGenerous when: !(thirsty or moving or bored) {
		if generosity >= 1.0 {
			generous <- true;
		} else {
			generous <- false;
		}

	}

	// Dance.
	reflex dance when: targetPoint = nil {
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

	// Check if at random point.
	reflex atRandomPoint when: random_point != nil and location distance_to (random_point) < building_interaction_distance {
		moving <- false;
		random_point <- nil;
		targetPoint <- nil;
		//write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") At Random Point";
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
					if self.targetPoint = nil and !(self.hungry or self.thirsty) {
						myself.random_point <- self.location + {rnd(guest_interaction_distance), rnd(guest_interaction_distance)};
						if myself.random_point.x > worldDimension {
							myself.random_point <- {worldDimension, myself.random_point.y};
						}

						if myself.random_point.y > worldDimension {
							myself.random_point <- {myself.random_point.x, worldDimension};
						}

						if myself.random_point.x < 0.0 {
							myself.random_point <- {0.0, myself.random_point.y};
						}

						if myself.random_point.y < 0.0 {
							myself.random_point <- {myself.random_point.x, 0.0};
						}

						myself.targetPoint <- myself.random_point;
						myself.boredom <- 0.8;
						myself.bored <- false;
						myself.boredom_count <- myself.boredom_count + 1;
						//write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + ") going to dance with (" + string(self.name) + ")";
						break;
					}

				}

			}

		}

	}

	// Leave the place when at exit.
	reflex leaveFestival when: leave and location distance_to (exitPoint) < building_interaction_distance {
		write "Cycle (" + string(cycle) + ") Agent (" + name + ") has left the event" + ((bored) ? " because he is bored." : ".");
		do die;
	}

	list<string> leave_msgs <- ['Get out', 'GET OUT YOU F***R'];
	// read inform msgs from security guard
	reflex receive_inform_msgs when: !empty(informs) {
	//write "Cycle (" + string(cycle) + ") Agent (" + name + ' receives a inform messages' + informs;
		loop information over: informs {

		// deal with security guard
			if (species(information.sender) = SecurityGuard) {
				switch information.contents[0] {
					match leave_msgs[0] {
						if (!bad) {
							write "Cycle (" + string(cycle) + ") Agent (" + (self.name) + ") says I am good";
							do start_conversation with: [to::list(information.sender), protocol::'fipa-contract-net', performative::'request', contents::['I am Good']];
						} else {
						// Not strict guard
						// fool guard and change location
							write "Cycle (" + string(cycle) + ") Agent (" + name + ' fooled ' + agent(information.sender).name;
							do start_conversation with: [to::list(information.sender), protocol::'fipa-contract-net', performative::'request', contents::['OK']];
							bad <- false; // turned into good guy
							random_point <- {rnd(worldDimension), rnd(worldDimension)};
							targetPoint <- random_point;
						}

					}

					match leave_msgs[1] {
						if (!bad) {
							write "Cycle (" + string(cycle) + ") Agent (" + (self.name) + ") says I am good";
							do start_conversation with: [to::list(information.sender), protocol::'fipa-contract-net', performative::'request', contents::['I am Good']];
						} else {
						// Strict guard
						// bribe if you have some money
							if (wallet > 100) {
								write "Cycle (" + string(cycle) + ") Agent (" + (self.name) + ") try to bribe " + wallet + " to (" + agent(information.sender).name + ")";
								do start_conversation with: [to::list(information.sender), protocol::'fipa-contract-net', performative::'request', contents::['BRIBE', wallet]];
							} else {
							// sincerely go out
								do start_conversation with: [to::list(information.sender), protocol::'fipa-contract-net', performative::'request', contents::['OK']];
								leave <- true;
								targetPoint <- exitPoint;
							}

						}

					}

				}

			} // deal with stages invitation and closure
else if (species(information.sender) = Stage) {
				if (information.contents[0] = 'Invitation') {
					stage_count <- stage_count + 1;
					// Evaluate utility of the act
					float current_utility <- get_utility(information.contents[1]);
					stage_utility <+ current_utility;
					stage_locs <+ agent(information.sender).location;
					stages <+ agent(information.sender).name;
					acts <+ information.contents[2];
					//write '\t(Time ' + time + '): ' + agent(information.sender).name + ' utility: ' + current_utility;
					// keep track of best stages
					if (current_utility > max_utility) {
						max_utility <- current_utility;
						best_stage_loc <- agent(information.sender).location;
						best_stage <- agent(information.sender);
						best_act <- information.contents[2];
					}

				} else if (information.contents[0] = 'Act ends') {
					stage_utility <- nil;
					stage_locs <- nil;
					max_utility <- 0.0;
					stage_count <- 0;
					all_stage_evaluated <- false;
					random_point <- {rnd(worldDimension), rnd(worldDimension)};
					targetPoint <- random_point;
				}

			}

		}
		// when all stages invitations are considered, go to best one
		if (stage_count = 3) {
			all_stage_evaluated <- true;
			stage_count <- 0;
		}

	}

	// read agree msg from security guard
	reflex receive_agree_msgs when: !empty(agrees) {
	// change location or turn into good guy
		message msg <- agrees[0];
		wallet <- wallet - int(msg.contents[1]);
		bad <- false;
		random_point <- {rnd(worldDimension), rnd(worldDimension)};
		targetPoint <- random_point;
	}

	// read refused msg from security guard
	reflex receive_refuse_msgs when: !empty(refuses) {
		leave <- true;
		targetPoint <- exitPoint;
	}

	// You'll agree for free drinks when thristy.
	reflex wantDrinkFromOthers when: thirst > 0.75 and !want_drink {
		want_drink <- true;
	}

	// Look for drinking buddies when feeling generous.
	reflex findDrinkingBuddies when: !bad and !moving and generous and drinkee_point = nil {
		list<FestivalGuest> neighbours <- FestivalGuest at_distance (5 * guest_interaction_distance);
		loop neighbour over: neighbours {
			ask neighbour {
				if !self.moving {
					myself.random_point <- {self.location.x + rnd(building_interaction_distance), self.location.y + rnd(building_interaction_distance)};
					myself.targetPoint <- myself.random_point;
					break;
				}

			}

		}

	}

	// Offer drink when feeling generous.
	reflex offerDrink when: !bad and !moving and generous and drinkee_point = nil {
		list<FestivalGuest> neighbours <- FestivalGuest at_distance (guest_interaction_distance);
		loop neighbour over: neighbours {
			ask neighbour {
				if !(self.moving or self.offered_drink) and self.want_drink {
					self.thirst <- 0.75;
					self.generosity <- 0.2;
					myself.thirst <- 1.0;
					self.offered_drink <- true;
					self.offerer <- FestivalGuest(myself);
					myself.generosity <- 0.25;
					myself.drinkee_point <-
					{self.location.x + rnd(-building_interaction_distance, building_interaction_distance), self.location.y + rnd(-building_interaction_distance, building_interaction_distance)};
					write "Cycle (" + string(cycle) + ")" + myself.name + " offered drink to " + self.name;
					break;
				}

			}

		}

	}

	// Receive drink from the offerer.
	reflex receiveDrink when: !bad and offered_drink {
		ask offerer {
			if self.location distance_to (myself.location) < guest_interaction_distance and self.has_drink {
				myself.thirst <- 0.25;
				myself.offered_drink <- false;
				myself.want_drink <- flip(0.2);
				myself.moving <- false;
				self.thirst <- 0.25;
				self.drinkee_point <- nil;
				self.has_drink <- false;
				myself.offerer <- nil;
				self.at_store <- true;
				self.random_point <- {rnd(worldDimension), rnd(worldDimension)};
				self.targetPoint <- self.random_point;
				myself.random_point <- {rnd(worldDimension), rnd(worldDimension)};
				myself.targetPoint <- myself.random_point;
				write "Cycle (" + string(cycle) + ")" + myself.name + " received drink from " + self.name;
			}

		}

	}

	// Reacting to Stages Invite------------------------
	// Utility function
	float get_utility (list<float> act_attributes) {
	// Add a more complex function for utility with atleast 6 variables
		float
		utility <- act_attributes[0] * my_preferences[0] + act_attributes[1] * my_preferences[1] + act_attributes[2] * my_preferences[2] + act_attributes[3] * my_preferences[3] + act_attributes[4] * my_preferences[4] + act_attributes[5] * my_preferences[5];
		return utility;
	}

	// Go to best stage
	reflex gotoBestStage when: all_stage_evaluated and !bad {
		do start_conversation with: [to::list(best_stage), protocol::'fipa-contract-net', performative::'inform', contents::['I am coming']];
		targetPoint <- best_stage_loc;
		targetPoint <- {targetPoint.x + rnd(-10, 10), targetPoint.y + rnd(8, 10)};
		best_utility <- stage_utility[stage_locs index_of (best_stage_loc)];
		write '\t(Time ' + time + '): ' + name + ' choice: ' + best_stage + " with utility " + best_utility;
		all_stage_evaluated <- false;
	}

}

//----------------------------------------------------Evil Guest Ends---------------------------------------------------------
//------------------------------------------------------Security Guard Begins------------------------------------------------------
species SecurityGuard skills: [moving, fipa] {
// Display icon of the information centre.
	image_file my_icon <- image_file("../includes/data/security.png");
	float icon_size <- 1 #m;

	aspect icon {
		draw my_icon size: 10 * icon_size;
	}

	bool hunting <- false;
	bool eliminated <- false;
	float corruptness <- rnd(0.0, 1.0);
	float strictness <- rnd(0.0, 1.0);
	bool isCorrupt <- flip(corruptness);
	bool isStrict <- flip(strictness);
	float wallet <- 0.0;
	point securityGuardPoint <- location;
	point targetPoint <- nil;
	EvilGuest bad_agent <- nil;
	list<string> leave_msgs <- ['Get out', 'GET OUT YOU F***R'];
	bool reached_bad_agent <- false;
	list<EvilGuest> badPeoples <- [];

	//new feature - added separetely to merge easier
	float violentness <- rnd(0.0, 1.0);
	bool isViolent <- flip(violentness);

	// Move to a given point.
	reflex moveToTarget when: targetPoint != nil {
		do goto target: targetPoint speed: move_speed * 2;
	}

	// Reflex change corruptness and strictness behaviors
	reflex courrupt_strict_modify when: (mod(int(time), 10000) = 0) {
		corruptness <- rnd(0.0, 1.0);
		strictness <- rnd(0.0, 1.0);
		isCorrupt <- flip(corruptness);
		isStrict <- flip(strictness);
		violentness <- rnd(0.0, 1.0);
		isViolent <- flip(violentness);
	}

	// Start conversing with evil guy
	reflex recive_request_from_evil_guy when: !empty(requests) and reached_bad_agent {
		message req <- requests[0];
		if (req.contents[0] = 'OK') {
			if (isStrict) {
			// escort the evil guy
				eliminated <- true;
				targetPoint <- exitPoint;
			} else {
			// assume he will go out himself. Guard is fooled by bad guy
				targetPoint <- securityGuardPoint;
				eliminated <- true;
				hunting <- false;
				reached_bad_agent <- false;
			}

		} else if (req.contents[0] = 'BRIBE') {
		// security guard takes bribe if he is corrupt
			if (isCorrupt) {
			// take bribe
				write "Cycle (" + string(cycle) + ") (" + name + ") takes " + string(req.contents[1]) + " bribe from (" + agent(req.sender).name + ")";
				do agree with: [message:: req, contents::['Enjoy', req.contents[1]]];
				wallet <- wallet + int(req.contents[1]);
				eliminated <- true;
				targetPoint <- securityGuardPoint;
				hunting <- false;
				reached_bad_agent <- false;
			} else {
			// escort the evil guy
				write "Cycle (" + string(cycle) + ") (" + name + ") refuse to take " + string(req.contents[1]) + " bribe from (" + agent(req.sender).name + ")";
				do refuse with: [message:: req, contents::[leave_msgs[1]]];
				eliminated <- true;
				targetPoint <- exitPoint;
				if isViolent {
					write "Cycle (" + string(cycle) + ") (" + name + ") insanely beating the evil guy";
					my_icon <- image_file("../includes/data/security_violent.png");
				}

			}

		} else if (req.contents[0] = 'I am Good') {

		// Either the agent has bribed or fooled before and now become good agent
			targetPoint <- securityGuardPoint;
			eliminated <- true;
			hunting <- false;
			reached_bad_agent <- false;
		}

		// Remove the guy from list (even if he wasn't removed because he could not be found).
		remove first(badPeoples) from: badPeoples;
		do inform_information_centre(bad_agent);
	}

	// action to inform information center
	action inform_information_centre (EvilGuest removed_agent) {
		do start_conversation with: [to::list(InformationCentre), protocol::'fipa-contract-net', performative::'inform', contents::['Removed', removed_agent]];
	}

	//Do not continue hunt when bad agent die out itself
	reflex discontinueHunt when: hunting and dead(bad_agent) {
		write "Cycle (" + string(cycle) + ") Agent (" + "bad agent killed himself.";
		targetPoint <- securityGuardPoint;
		eliminated <- true;
		hunting <- false;
		reached_bad_agent <- false;
	}

	// Hunts bad people one by one
	reflex getTarget when: length(badPeoples) > 0 and !hunting {
		if !dead(badPeoples[0]) {
			bad_agent <- badPeoples[0];
			targetPoint <- bad_agent.location;
			hunting <- true;
		} else {
			write "Cycle (" + string(cycle) + ") Agent (" + badPeoples[0] + " is already dead.";
			do inform_information_centre(badPeoples[0]);
			remove badPeoples[0] from: badPeoples;
		}

	}

	// Maintain a list of bad peoples
	reflex recieve_msgs_from_info_center when: !empty(informs) {
		message inf <- informs[0];
		badPeoples <+ inf.contents[1];
	}

	// Inititiate talk when reached to bad agent
	reflex nearTarget when: hunting and location distance_to (targetPoint) < building_interaction_distance and !reached_bad_agent {
		reached_bad_agent <- true;
		if (!isStrict) {
			do start_conversation with: [to::list(bad_agent), protocol::'fipa-contract-net', performative::'inform', contents::[leave_msgs[0]]];
		} else {
			do start_conversation with: [to::list(bad_agent), protocol::'fipa-contract-net', performative::'inform', contents::[leave_msgs[1]]];
		}

	}

	// Change state when at secturity post.
	reflex atSecurityPost when: location distance_to (securityGuardPoint) < building_interaction_distance {
		hunting <- false;
		eliminated <- false;
	}

	// Change state when at exit gate.
	reflex atExitGate when: eliminated or location distance_to (exitPoint) < building_interaction_distance {
		targetPoint <- securityGuardPoint;
		hunting <- false;
		eliminated <- false;
		reached_bad_agent <- false;
		my_icon <- image_file("../includes/data/security.png");
	} }

	//------------------------------------------------------Security Guard Ends------------------------------------------------------


//------------------------------------------------------Information Centre Begins------------------------------------------------------
species InformationCentre skills: [fipa] {
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
	list<SecurityGuard> sg_list <- [];
	list<EvilGuest> badPeoples <- [];
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
		create SecurityGuard number: 1 with: (location: securityGuardPoint) returns: sg;
		sg_list <- sg;
	}

	// Gets the location of the baddies from the guest who has come to complain.
	reflex guestComplaint {
		list<FestivalGuest> guests <- FestivalGuest at_distance (building_interaction_distance);
		loop guest over: guests {
			ask guest {
				if self.near_bad {
					if !(self.bad_agent in myself.badPeoples) {
						myself.badPeoples <+ self.bad_agent;
						self.near_bad <- false;
						self.bad_location <- nil;
						self.bad_agent <- nil;
						self.random_point <- {rnd(worldDimension), rnd(worldDimension)};
						self.targetPoint <- self.random_point;
						self.at_store <- true; // To reset the state of the person. No significance to reporting of bad person.
						// Inform security guard to remove agents
						do start_conversation with: [to::myself.sg_list, protocol::'fipa-contract-net', performative::'inform', contents::['Remove', myself.badPeoples[0]]];
						write "\nCycle (" + string(cycle) + ") Agent (" + myself.name + ") Bad Guy Reported by (" + self.name + ")";
						write "Cycle (" + string(cycle) + ") Agent (" + myself.name + ") " + string(length(myself.badPeoples)) + " complaint(s)." + myself.badPeoples;
					}

				}

			}

		}

	}

	// Update the bad people list
	reflex recieve_msgs_from_guard when: !empty(informs) {
		message inf <- informs[0];
		if (inf.contents[0] = 'Removed') {
			remove (inf.contents[1]) from: badPeoples;
			write "\nCycle (" + string(cycle) + ") Agent (" + name + ") Removed trouble maker (" + string(inf.contents[1]) + ")";
			write "Cycle (" + string(cycle) + ") Agent (" + name + ") " + string(length(badPeoples)) + " complaint(s)." + badPeoples;
		}

	} }

	//------------------------------------------------------Information Centre Ends------------------------------------------------------

//------------------------------------------------------Journalist Begins------------------------------------------------------
species Journalist skills: [moving, fipa] {
// Display icon of the food shop.
	image_file my_icon <- image_file("../includes/data/journalist.png");
	float icon_size <- 1 #m;

	aspect icon {
		draw my_icon size: 7 * icon_size;
	}

	float max_curious <- 1.0;
	float curiosity_consum <- 0.00001;

	// Hunger and thirst updates.
	float hunger <- rnd(max_hunger) update: hunger + 0.5 * hunger_consum max: max_hunger;
	float thirst <- rnd(max_thirst) update: thirst + 0.5 * thirst_consum max: max_thirst;
	float curiosity <- rnd(0.2, max_curious) update: curiosity - curiosity_consum min: 0.0 max: max_curious;

	// State variables.
	bool hungry <- false;
	bool thirsty <- false;
	bool curious <- true;
	bool moving <- false;
	bool at_info <- false;
	bool at_store <- false;
	bool leave <- false;
	int interviewed_count <- 0;
	int max_interviewed_count <- int(number_of_guests / 2.5);
	bool interviewing <- false;
	list<point> foodPoints <- nil;
	point foodPoint <- nil;
	list<point> drinksPoints <- nil;
	point drinksPoint <- nil;
	point random_point <- nil;
	point targetPoint <- nil;
	bool controversial_questions <- flip(0.5);

	// Stage variables
	list<float> my_preferences <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)]; //1.Lightshow 2.Speakers 3.Band 4.Seats 5.Food 6.Popularity
	list<point> stage_locs <- nil;
	list<float> stage_utility <- nil;
	list<string> stages <- nil;
	point best_stage_loc <- nil;
	agent best_stage <- nil;
	float best_utility <- 0.0;
	list<string> acts <- nil;
	string best_act <- nil;
	bool all_stage_evaluated <- false;
	float max_utility <- 0.0;
	int stage_count <- 0;

	// Check if hungry or not. Don't change priority if already doing something.
	reflex isHungry when: !(thirsty or moving) {
		if hunger = 1.0 {
			hungry <- true;
		} else {
			hungry <- false;
		}

	}

	// Check if thirsty or not. Don't change priority if already doing something.
	reflex isThirsty when: !(hungry or moving) {
		if thirst = 1.0 {
			thirsty <- true;
		} else {
			thirsty <- false;
		}

	}

	// Check if curious or not. Don't change priority if already doing something.
	reflex isCurious when: !(hungry or thirsty or moving) {
		if curiosity = 0.0 {
			curious <- false;
		} else {
			curious <- true;
		}

	}

	// Move to a given point.
	reflex moveToTarget when: targetPoint != nil {
		do goto target: targetPoint speed: move_speed * ((curious) ? 2 : 1);
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
						break;
					} else if myself.thirsty and self.drinksPoint != nil {
						myself.drinksPoints <- self.drinksPoints;
						myself.drinksPoint <- any(myself.drinksPoints);
						myself.targetPoint <- myself.drinksPoint;
						myself.at_info <- true;
						asked <- true;
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
	}

	// Get store location from information centre.
	reflex getStoreLocation when: (hungry or thirsty) and at_info and !at_store {
		ask InformationCentre {
		// Ask for food/drink when hungry/thirsty and don't know the location.
			if myself.hungry and myself.foodPoint = nil {
				myself.foodPoints <- self.foodPoints;
				myself.foodPoint <- any(myself.foodPoints);
				myself.targetPoint <- myself.foodPoint;
			}

			if myself.thirsty and myself.drinksPoint = nil {
				myself.drinksPoints <- self.drinksPoints;
				myself.drinksPoint <- any(myself.drinksPoints);
				myself.targetPoint <- myself.drinksPoint;
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
		curiosity <- curiosity + 0.2;
		curious <- true;
		random_point <- {rnd(worldDimension), rnd(worldDimension)};
		targetPoint <- random_point;
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
		curiosity <- curiosity + 0.2;
		curious <- true;
		random_point <- {rnd(worldDimension), rnd(worldDimension)};
		targetPoint <- random_point;
	}

	// Check if at random point.
	reflex atRandomPoint when: at_store and random_point != nil and location distance_to (random_point) < building_interaction_distance {
		at_store <- false;
		at_info <- false;
		moving <- false;
		random_point <- nil;
		targetPoint <- nil;
	}

	// Interview the closest person. If no person then leave.
	reflex interview when: curious and !interviewing and !moving {
		if interviewed_count >= max_interviewed_count {
			leave <- true;
			targetPoint <- exitPoint;
		} else {
			list<FestivalGuest> neighbours <- FestivalGuest at_distance (5 * guest_interaction_distance);
			if length(neighbours) = 0 {
				neighbours <- list(FestivalGuest closest_to (location));
			}

			if neighbours[0] = nil {
				leave <- true;
				targetPoint <- exitPoint;
			} else {
				ask neighbours {
					if !myself.interviewing and self.want_to_be_interviewed and self.targetPoint = nil and !(self.hungry or self.thirsty) {
						myself.random_point <- self.location + {rnd(0.4 * guest_interaction_distance), rnd(0.4 * guest_interaction_distance)};
						if myself.random_point.x > worldDimension {
							myself.random_point <- {worldDimension, myself.random_point.y};
						}

						if myself.random_point.y > worldDimension {
							myself.random_point <- {myself.random_point.x, worldDimension};
						}

						if myself.random_point.x < 0.0 {
							myself.random_point <- {0.0, myself.random_point.y};
						}

						if myself.random_point.y < 0.0 {
							myself.random_point <- {myself.random_point.x, 0.0};
						}

						myself.targetPoint <- myself.random_point;
						myself.random_point <- nil;
						myself.at_store <- true;
						myself.curiosity <- myself.curiosity + 0.5;
						myself.curious <- true;
						myself.interviewing <- true;
						self.being_interviewed <- true;
						self.want_to_be_interviewed <- flip(0.5);
						write "Cycle (" + string(cycle) + ") Agent (" + myself.name + ") interviewing (" + self.name + ")";
						if (myself.controversial_questions) {
							if (!self.friendly) {
								write "Cycle (" + string(cycle) + ") Agent (" + myself.name + ") interview is ruined by (" + self.name + ")" + " because of controversial questions\n";
								myself.interviewing <- false;
								random_point <- {rnd(worldDimension), rnd(worldDimension)};
								targetPoint <- random_point;
								break;
							}

						}

						break;
					}

				}

			}

		}

	}

	reflex doneInterviewing when: interviewing and mod(cycle, 10000) = 0 {
		interviewed_count <- interviewed_count + 1;
		interviewing <- false;
		random_point <- {rnd(worldDimension), rnd(worldDimension)};
		targetPoint <- random_point;
	}

	reflex leaveWhenNotCurious when: !curious {
		leave <- true;
		targetPoint <- exitPoint;
	}

	// Leave the place when at exit.
	reflex leaveFestival when: leave and location distance_to (exitPoint) < building_interaction_distance {
		write "Cycle (" + string(cycle) + ") Agent (" + name + ") has left the event" + ((curious) ? " because he is not curious anymore." : ".");
		do die;
	}
	// Reacting to Stages Invite------------------------
	// Utility function
	float get_utility (list<float> act_attributes) {
	// Add a more complex function for utility with atleast 6 variables
		float
		utility <- act_attributes[0] * my_preferences[0] + act_attributes[1] * my_preferences[1] + act_attributes[2] * my_preferences[2] + act_attributes[3] * my_preferences[3] + act_attributes[4] * my_preferences[4] + act_attributes[5] * my_preferences[5];
		return utility;
	}

	// Read inform msgs from stages.
	reflex receive_inform_messages when: !empty(informs) and !interviewing {
	//write '\n(Time ' + time + '): ' + name + ' receives inform messages.' + informs;
		loop information over: informs {
			if (string(information.contents[0]) = 'Invitation') {
				stage_count <- stage_count + 1;
				// Evaluate utility of the act
				float current_utility <- get_utility(information.contents[1]);
				stage_utility <+ current_utility;
				stage_locs <+ agent(information.sender).location;
				stages <+ agent(information.sender).name;
				acts <+ information.contents[2];
				//write '\t(Time ' + time + '): ' + agent(information.sender).name + ' utility: ' + current_utility;
				// keep track of best stages
				if (current_utility > max_utility) {
					max_utility <- current_utility;
					best_stage_loc <- agent(information.sender).location;
					best_stage <- agent(information.sender);
					best_act <- information.contents[2];
				}

			} else if (string(information.contents[0]) = 'Act ends') {
				stage_utility <- nil;
				stage_locs <- nil;
				max_utility <- 0.0;
				stage_count <- 0;
				all_stage_evaluated <- false;
				random_point <- {rnd(worldDimension), rnd(worldDimension)};
				targetPoint <- random_point;
			}

		}

		// when all stages invitations are considered, go to best one
		if (stage_count = 3) {
			all_stage_evaluated <- true;
			stage_count <- 0;
		}

	}

	// Go to best stage
	reflex gotoBestStage when: all_stage_evaluated {
		do start_conversation with: [to::list(best_stage), protocol::'fipa-contract-net', performative::'inform', contents::['I am coming']];
		targetPoint <- best_stage_loc;
		targetPoint <- {targetPoint.x + rnd(-10, 10), targetPoint.y + rnd(8, 10)};
		best_utility <- stage_utility[stage_locs index_of (best_stage_loc)];
		write '\t(Time ' + time + '): ' + name + ' choice: ' + best_stage + " with utility " + best_utility;
		all_stage_evaluated <- false;
	}

	reflex leaveOnFestivalEnd when: mod(cycle, 10000) = 0 {
		int remaining <- length(FestivalGuest) + length(EvilGuest);
		if remaining = 0 {
			curious <- false;
		}

	}

}

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

// --------------------------------------------------Stage Begins---------------------------------------------------
species Stage skills: [fipa] {

// Stage variables
	int act_duration <- 10000;
	int rest_duration <- 50000;
	bool showing_act <- false;
	string role <- nil;
	list<float> act_attributes <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)]; //1.Lightshow 2.Speakers 3.Band 4.Seats 5.Food 6.Popularity
	list<agent> audience <- nil;

	//Send invitation to all guests in the festival to join stage shows.
	reflex informGuestsAboutActs when: mod(int(time), (act_duration + rest_duration)) = 0 and int(time) > 0 {
		role <- any(['band', 'singer', 'dancer']);
		if !empty(list(FestivalGuest + EvilGuest + Journalist)) {
			write '\n(Time ' + time + '): ' + name + ' sends a invitation to all the guests.';
			do start_conversation with:
			[to::list(FestivalGuest + EvilGuest + Journalist), protocol::'fipa-contract-net', performative::'inform', contents::['Invitation', act_attributes, role]];
		} else {
			write '\t(Time ' + time + '): ' + name + ' ALL DEAD. No one to invite.';
		}

	}

	//Send end information to all guests in the festival to leave stage shows.
	reflex informGuestsActsEnding when: showing_act and mod(int(time), act_duration) = 0 and mod(int(time), (act_duration + rest_duration)) != 0 and length(audience) != 0 {
		write '\n(Time ' + time + '): ' + name + ' sends a act closure to the audience.';
		do start_conversation with: [to::audience, protocol::'fipa-contract-net', performative::'inform', contents::['Act ends', role]];
		showing_act <- false;
		audience <- nil;
	}

	// Make a record of guests
	reflex getlistofinterestedguests when: !empty(informs) {
		loop information over: informs {
			if (string(information.contents[0]) = 'I am coming') {
				audience <+ agent(information.sender);
			}

		}

		if length(audience) > 0 {
			showing_act <- true;
		}

	}

	// Change act attributes once it ends
	reflex newActAttributes when: mod(int(time), act_duration) = 0 {
		act_attributes <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)]; //1.Lightshow 2.Speakers 3.Band 4.Seats 5.Food 6.Popularity
	}

	image_file my_icon <- image_file("../includes/data/stages/" + role + ".png");
	list<rgb> mycolors <- [rgb(192, 252, 15, 100), rgb(15, 192, 252, 100), rgb(252, 15, 192, 100)];

	aspect icon {
		draw my_icon size: 10;
	}

	// Display character of the guest.
	aspect range {
		if (showing_act) {
			draw circle(8) color: any(mycolors) border: #black;
		} else {
			draw circle(8) color: mycolors[1] border: #black;
		}

	}

}
// --------------------------------------------------Stage Ends---------------------------------------------------
// Experiment.
experiment festival type: gui {
	output {
	// Display map.
		display myDisplay type: opengl {
			species FestivalGuest aspect: icon;
			species EvilGuest aspect: icon;
			species InformationCentre aspect: icon refresh: false;
			species FoodShop aspect: icon refresh: false;
			species DrinksShop aspect: icon refresh: false;
			species SecurityGuard aspect: icon;
			species ExitGate aspect: icon refresh: false;
			species Journalist aspect: icon;
			species Stage aspect: range;
			species Stage aspect: icon;
		}

		//inspect "journalist inspector" value: Journalist attributes: ["interviewed_count", "moving", "interviewing", "curious"];
		//inspect "guest" value: FestivalGuest attributes: ["bored"] type: table;
		//inspect "evil guest" value: EvilGuest attributes: ["bored", "bad"] type: table;
		//inspect "guard" value: SecurityGuard attributes: ["wallet", "isCorrupt", "isStrict"] type: table;
		//inspect "stage" value: Stage attributes: ["showing_act"] type: table;
		//inspect "evilguest2" value: EvilGuest attributes: ["generous", "want_drink", "offered_drink", "has_drink", "drinkee_point", "offerer"] type: table;
		//inspect "shyness" value: FestivalGuest attributes: ["friendly"];
	}

}
