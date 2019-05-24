# Rasp-menu project!

## Targets

The last scope of this project is to have a terminal menu to be able to have in linux's ambient.

In principle it should be the great abstract possible, but in the first release the software will be able to do specific menu.

## Requirements
The minus requirements are:

- *`Linux OS`*: necessary to run the script
- *`whiptail`*:  is a program that allows shell scripts to display dialog boxes to the user for informational purposes, or to get input from the user in a friendly way.

## Installation
The menu is a bash script that use the program *`whiptail`* to render a minimal dialog boxes.
It can take some arguments in input (depends on box-option) and can be summarize like:
```
whiptail [<whiptail-arg>] <box-option> [<args-of-option>] <height> <width> [<other-dimension-parameters>]
```
- `whiptail-arg (optional)`: in general is the *title* of the box
- `box-option`: the box that we want to visualize:

	-	message box 
	- yes/no box 
	- info box 
	- input box 
	- password box 
	- text box 
	- menu box
	- checklist box
	- radio list box 
	- gauge box

For example we can create a info box with this command:
```
whiptail --title "Example Dialog" --infobox "This is an example of an info box." 8 78
```

## How use it
After creating a bash script it must be executable and is possible with this command:
```
chown u+x </path/to/file>
```

## Future developments
The next step of this menu is to create it dynamically and where we can add or delete a option (or more option) in a manner very simple and easier. 
