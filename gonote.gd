@tool
extends Control

"""
GoNote: In-editor Notepad
Author: @Kreaytore
Created: December 14th, 2024
"""

const LOCAL_SAVED_NOTES_FILEPATH: String = "res://addons/GoNote/saved_notes/"

#region Containers and Home Vars
@onready var note_tab_container = $MarginContainer/VBoxContainer/NoteTabContainer
@onready var note_options_hbox = $MarginContainer/VBoxContainer/Button_Container_Hbox/NoteOptionsHbox
@onready var home = $MarginContainer/VBoxContainer/NoteTabContainer/Home
@onready var save_label = $MarginContainer/VBoxContainer/Button_Container_Hbox/NoteOptionsHbox/Save_Hbox/SaveLabel
@onready var save_note_local_button = $MarginContainer/VBoxContainer/Button_Container_Hbox/NoteOptionsHbox/Save_Hbox/SaveNoteLocalButton
#endregion

#region Note Vars
var current_tab_index: int = 0
var current_text_box_node: TextEdit = null

const MAX_NEW_NOTE_NAME_LENGTH: int = 40
const NOTE_PLACEHOLDER_TEXT: String = "I am an empty note... Please write on me...!"

var current_note_unsaved: bool = false
var saved_note_names_for_save_check = null
var saved_note_contents_for_save_check = ""
const UNSAVED_TEXT = "[color=#FF0000][right]* PLEASE SAVE NOTE CHANGES *[/right][/color]"
const SAVED_TEXT = "[color=green][right]UNCHANGED[/right][/color]"
#endregion

#region Filename Vars
@onready var new_note_button = $"MarginContainer/VBoxContainer/Button_Container_Hbox/NewNoteHbox/New Note Button"
@onready var new_note_line_edit = $MarginContainer/VBoxContainer/Button_Container_Hbox/NewNoteHbox/NewNoteLineEdit

var filename_is_valid = false
var new_text_filename = ""
# Filenames aren't allowed to have these in Windows and in Node Names. Idk about Linux and Mac.
const INVALID_FILENAME_CHARS = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
const INVALID_NODENAME_CHARS = [".", ":", "@", "/", "\"", "%"]
#endregion

#region Ready, Process, and Filename checking
func _ready():
	new_note_line_edit.set_max_length(MAX_NEW_NOTE_NAME_LENGTH)
	set_to_home_tab()
	
	if not DirAccess.dir_exists_absolute(LOCAL_SAVED_NOTES_FILEPATH):
		DirAccess.make_dir_absolute(LOCAL_SAVED_NOTES_FILEPATH)
		
		scan_project_filesystem()
	
	load_saved_notes()

func _input(event):
	if event is InputEventKey and event.is_pressed():
		if event.get_keycode() == KEY_S and event.is_ctrl_pressed():
			if current_tab_index != 0 and current_text_box_node != null:
				_on_save_note_local_button_pressed()

func _process(delta):
	check_new_file_name_input()
	check_if_not_saved()
	
	if filename_is_valid:
		if new_note_button.is_disabled():
			new_note_button.set_disabled(false)
	else:
		if not new_note_button.is_disabled():
			new_note_button.set_disabled(true)
	
	if note_tab_container.get_current_tab() == 0: # 0 is the Home tab.
		if note_options_hbox.is_visible():
			note_options_hbox.set_visible(false)
	else:
		if not note_options_hbox.is_visible():
			note_options_hbox.set_visible(true)

func check_new_file_name_input():
	if new_text_filename == "":
		filename_is_valid = false
		return
	
	for char in new_text_filename:
		if char in INVALID_FILENAME_CHARS:
			filename_is_valid = false
			return
	
	for char in new_text_filename:
		if char in INVALID_NODENAME_CHARS:
			filename_is_valid = false
			return
	
	for child in note_tab_container.get_children():
		if new_text_filename.to_lower() == child.get_name().to_lower():
				filename_is_valid = false
				return
	
	filename_is_valid = true
#endregion

#region Creating Note Funcs
func _on_new_note_button_pressed():
	if filename_is_valid:
		if new_note_line_edit.get_text() != "" and new_text_filename != "":
			var new_note = TextEdit.new()
			new_note.set_name(new_text_filename)
			new_note.set_placeholder(NOTE_PLACEHOLDER_TEXT)
			
			note_tab_container.add_child(new_note)
			
			new_note_line_edit.menu_option(LineEdit.MenuItems.MENU_CLEAR)
		else:
			push_warning("GoNote: Tried creating a new note with an empty name.")
	else:
		push_warning("GoNote: New Note button pressed but note has an invalid name.")

func _on_new_note_line_edit_text_changed(new_text):
	new_text_filename = new_text.strip_edges()

func _on_new_note_line_edit_text_submitted(new_text):
	if filename_is_valid:
		new_note_button.emit_signal("pressed")

func _on_tab_container_tab_selected(tab):
	if tab != 0:
		current_tab_index = tab
		current_text_box_node = note_tab_container.get_current_tab_control()
		get_note_contents_save_check(tab, current_text_box_node)
	else:
		current_text_box_node = null
#endregion

#region Deleting and Clearing Funcs
func _on_clear_text_button_pressed():
	if current_tab_index != 0:
		if current_text_box_node != null:
			current_text_box_node.menu_option(TextEdit.MenuItems.MENU_CLEAR)
		else:
			push_warning("GoNote: Tried to clear a note that doesn't exist.")
	else:
		push_warning("GoNote: Tried to clear a note at a null index.")

func _on_delete_note_button_pressed():
	if current_tab_index != 0:
		if current_text_box_node != null:
			note_tab_container.remove_child(note_tab_container.get_child(current_tab_index))
			
			if DirAccess.dir_exists_absolute(LOCAL_SAVED_NOTES_FILEPATH):
				if not DirAccess.get_files_at(LOCAL_SAVED_NOTES_FILEPATH).is_empty():
					var file_to_delete_name = current_text_box_node.get_name() + ".txt"
					
					if FileAccess.file_exists(LOCAL_SAVED_NOTES_FILEPATH + file_to_delete_name):
						DirAccess.remove_absolute(LOCAL_SAVED_NOTES_FILEPATH + file_to_delete_name)
						
						scan_project_filesystem()
					else:
						pass
						#push_warning("GoNote: Tried to delete a saved note that doesn't exist.")
				else:
					push_warning("GoNote: Tried to delete a saved note but there are no notes saved.")
			else:
				push_warning("GoNote: Tried to delete a saved note but the directory doesn't exist.")
			
			set_to_home_tab()
		else:
			push_warning("GoNote: Tried to delete a note that doesn't exist.")
	else:
		push_warning("GoNote: Tried to delete a note at a null index.")
#endregion

#region Loading and Saving Funcs
func _on_save_note_local_button_pressed():
	if not DirAccess.dir_exists_absolute(LOCAL_SAVED_NOTES_FILEPATH):
		DirAccess.make_dir_absolute(LOCAL_SAVED_NOTES_FILEPATH)
		
		scan_project_filesystem()
	
	if current_tab_index != 0:
		if current_text_box_node != null:
			var new_filename = current_text_box_node.get_name() + ".txt"
			var new_filepath = LOCAL_SAVED_NOTES_FILEPATH + new_filename
			
			var new_note_to_save = FileAccess.open(new_filepath, FileAccess.WRITE)
			if new_note_to_save:
				new_note_to_save.store_string(current_text_box_node.get_text())
				new_note_to_save.close()
				
				get_note_contents_save_check(current_tab_index, current_text_box_node)
				
				scan_project_filesystem()
				
			else:
				push_warning("GoNote: Failed to write new text file.")
		else:
			push_warning("GoNote: Tried to save a note that doesn't exist.")
	else:
		push_warning("GoNote: Tried to save a note at a null index.")

func load_saved_notes():
	"""
		This func deletes all the note tabs when called.
		If I were adding a function that could load closed notes from the
		filesystem, then this would matter.
		But it doesn't, cause deleting a note also deletes it's saved data.
		So yea. Don't worry about it bruh
	"""
	for child in note_tab_container.get_children():
		if child != home:
			child.queue_free()
			
	if DirAccess.dir_exists_absolute(LOCAL_SAVED_NOTES_FILEPATH):
		if not DirAccess.get_files_at(LOCAL_SAVED_NOTES_FILEPATH).is_empty():
			var all_saved_note_names = DirAccess.get_files_at(LOCAL_SAVED_NOTES_FILEPATH)
			for note in all_saved_note_names:
				var new_node_name = note.trim_suffix(".txt")
				
				var new_note_node = TextEdit.new()
				new_note_node.set_name(new_node_name)
				new_note_node.set_placeholder(NOTE_PLACEHOLDER_TEXT)
				
				var file_to_load = FileAccess.open(LOCAL_SAVED_NOTES_FILEPATH + note, FileAccess.READ)
				var file_contents = file_to_load.get_as_text()
				new_note_node.set_text(file_contents)
				
				note_tab_container.add_child(new_note_node)
			
			scan_project_filesystem()

func get_note_contents_save_check(note_index: int, note_box: TextEdit):
	if note_index != 0 and note_box != null:
		if DirAccess.dir_exists_absolute(LOCAL_SAVED_NOTES_FILEPATH):
			if not DirAccess.get_files_at(LOCAL_SAVED_NOTES_FILEPATH).is_empty():
				saved_note_names_for_save_check = DirAccess.get_files_at(LOCAL_SAVED_NOTES_FILEPATH)
				
				var note_name = note_box.get_name() + ".txt"
				
				if FileAccess.file_exists(LOCAL_SAVED_NOTES_FILEPATH + note_name):
					var file_to_load = FileAccess.open(LOCAL_SAVED_NOTES_FILEPATH + note_name, FileAccess.READ)
					saved_note_contents_for_save_check = file_to_load.get_as_text()

func check_if_not_saved():
	if current_tab_index != 0 and current_text_box_node != null:
		if not saved_note_contents_for_save_check == "":
			if current_text_box_node.get_text() != saved_note_contents_for_save_check:
				save_label.set_text(UNSAVED_TEXT)
				current_note_unsaved = true
			else:
				save_label.set_text(SAVED_TEXT)
				current_note_unsaved = false
#endregion

#region Misc Funcs
# This is basically a "reset" function
func set_to_home_tab():
	new_text_filename = ""
	current_tab_index = 0
	current_text_box_node = null
	current_note_unsaved = false
	saved_note_names_for_save_check = null
	saved_note_contents_for_save_check = ""
	
	note_tab_container.set_current_tab(0)

func scan_project_filesystem():
	"""
		I don't know why but I fucking LOVE this function.
		I can't explain it it's so cool.
		Probably cause I just learned about fileystem scanning in my
		Dragonfruit project. It's so cool and useful goddamn. ~ Kreaytore
	"""
	if not EditorInterface.get_resource_filesystem().is_scanning():
		EditorInterface.get_resource_filesystem().scan()
#endregion
