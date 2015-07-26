*&---------------------------------------------------------------------*
*& Report  z_hello_salv_editable2.
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*

report  z_hello_salv_editable2.

*----------------------------------------------------------------------*
*  Define the Local class inheriting from the CL_SALV_MODEL_LIST
*  to get an access of the model, controller and adapter which inturn
*  provides the Grid Object
*----------------------------------------------------------------------*
class lcl_salv_model definition inheriting from cl_salv_model_list.
  public section.
    data: lo_control type ref to cl_salv_controller_model,
          lo_adapter type ref to cl_salv_adapter.
    methods:
      grabe_model
        importing
          io_model type ref to cl_salv_table,
       grabe_controller,
       grabe_adapter.
  private section.
    data: lo_model type ref to cl_salv_model.
endclass.                    "LCL_SALV_MODEL DEFINITION
*----------------------------------------------------------------------*
* Event handler for the added buttons
*----------------------------------------------------------------------*
class lcl_event_handler definition.
  public section.
    methods:
      on_user_command for event added_function of cl_salv_events
        importing e_salv_function,
      handle_data_changed for event data_changed of cl_gui_alv_grid
        importing er_data_changed.
endclass.                    "lcl_event_handler DEFINITION
*----------------------------------------------------------------------*
* Local Report class - Definition
*----------------------------------------------------------------------*
class lcl_report definition.
  public section.
    types: ty_t_sflights type standard table of sflights.
    data: t_data type ty_t_sflights.
    data: lo_salv       type ref to cl_salv_table.
    data: lo_salv_model type ref to lcl_salv_model.
    methods:
      get_data,
      generate_output.
endclass.                    "lcl_report DEFINITION






*----------------------------------------------------------------------*
* Main logic
*----------------------------------------------------------------------*

*----------------------------------------------------------------------*
* Global data
*----------------------------------------------------------------------*
data: lo_report type ref to lcl_report.
*----------------------------------------------------------------------*
* Start of selection
*----------------------------------------------------------------------*
start-of-selection.
  create object lo_report.
  lo_report->get_data( ).
  lo_report->generate_output( ).







*----------------------------------------------------------------------*
* Local Report class - Implementation
*----------------------------------------------------------------------*
class lcl_report implementation.
  method get_data.
*   test data
    select * from sflights
           into table me->t_data
           up to 30 rows.
  endmethod.                    "get_data
  method generate_output.
*...New ALV Instance ...............................................
    try.
        cl_salv_table=>factory(
           exporting
             list_display = abap_false
           importing
             r_salv_table = lo_salv
           changing
             t_table      = t_data ).
      catch cx_salv_msg.                                "#EC NO_HANDLER
    endtry.

*   SET PF-status
    lo_salv->set_screen_status(
      pfstatus      = 'SALV_STANDARD'
      report        = sy-repid
      set_functions = lo_salv->c_functions_all ).

*   Event handler for the button, to make edit button work
    data: lo_events   type ref to cl_salv_events_table,
          lo_event_h  type ref to lcl_event_handler.

*   event object
    lo_events = lo_salv->get_event( ).
*   event handler
    create object lo_event_h.
*   setting up the event handler
    set handler lo_event_h->on_user_command for lo_events.

*   object for the local inherited class from the CL_SALV_MODEL_LIST
    create object lo_salv_model.
*   grabe model to use it later
    call method lo_salv_model->grabe_model
      exporting
        io_model = lo_salv.

    lo_salv->display( ).
  endmethod.                    "generate_output
endclass.                    "lcl_report IMPLEMENTATION
*----------------------------------------------------------------------*
* LCL_SALV_MODEL implementation
*----------------------------------------------------------------------*
class lcl_salv_model implementation.
  method grabe_model.
*   save the model
*   Get Model Object - narrow cast from cl_salv_table to cl_salv_model
    lo_model ?= io_model.
  endmethod.                    "grabe_model
  method grabe_controller.
*   save the controller
    lo_control = lo_model->r_controller.
  endmethod.                    "grabe_controller
  method grabe_adapter.
*   save the adapter from controller
    lo_adapter ?= lo_model->r_controller->r_adapter.
  endmethod.                    "grabe_adapter
endclass.                    "LCL_SALV_MODEL IMPLEMENTATION
*----------------------------------------------------------------------*
* Event Handler for the SALV
*----------------------------------------------------------------------*
class lcl_event_handler implementation.
  method on_user_command.
    data: lo_grid type ref to cl_gui_alv_grid,
          lo_full_adap type ref to cl_salv_fullscreen_adapter.
    data: ls_layout type lvc_s_layo,
          ls_fieldcat type lvc_t_fcat,
          ls_modified_cells type lvc_s_moce.
    field-symbols <fs_alv_fieldcat> like line of ls_fieldcat.

    case e_salv_function.
* Make ALV as Editable ALV
      when 'EDIT'.
* Contorller
        call method lo_report->lo_salv_model->grabe_controller.
* Adapter
        call method lo_report->lo_salv_model->grabe_adapter.
* Fullscreen Adapter (Down Casting)
        lo_full_adap ?= lo_report->lo_salv_model->lo_adapter.
* Get the Grid
        lo_grid = lo_full_adap->get_grid( ).
* Register edit event
        lo_grid->register_edit_event( exporting i_event_id = cl_gui_alv_grid=>mc_evt_enter ).
        lo_grid->register_edit_event( exporting i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
        set handler handle_data_changed for lo_grid.

*       Got the Grid .. ?
        if lo_grid is bound.

* Here we can make all alv editable
*          call method lo_grid->get_frontend_layout
*            importing
*              es_layout = ls_layout.
*          IF ls_layout-edit = ''.
*            ls_layout-edit = 'X'.
*          ELSE.
*            CLEAR ls_layout-edit.
*          ENDIF.
**           Set the front layout of ALV
*          CALL METHOD lo_grid->set_frontend_layout
*            EXPORTING
*              is_layout = ls_layout.

* Make only one field editable

          call method lo_grid->get_frontend_fieldcatalog
            importing
              et_fieldcatalog = ls_fieldcat.

          loop at ls_fieldcat assigning <fs_alv_fieldcat>.
            if <fs_alv_fieldcat>-fieldname = 'CARRNAME'.
              if <fs_alv_fieldcat>-edit = abap_false.
                <fs_alv_fieldcat>-edit = 'X'.
              else.
                clear <fs_alv_fieldcat>-edit.
              endif.
            endif.
          endloop.

          call method lo_grid->set_frontend_fieldcatalog
            exporting
              it_fieldcatalog = ls_fieldcat.

*         refresh the table
          call method lo_grid->refresh_table_display.
        endif.

      when 'SAVE'.
        message 'Here we save "t_data" to database' type 'W'.

    endcase.
  endmethod.                    "on_user_command
  method handle_data_changed.

    " Here we can print changed data for example
    data: lt_mod_cells  type lvc_t_modi,
          ls_mod_cells  type lvc_s_modi,
          lv_message    type string.
    field-symbols: <fs_mod_cells> type lvc_s_modi,
                   <ft_mod_rows>  type table,
                   <fs_mod_rows>  type any,
                   <fs>           type any.

    assign er_data_changed->mp_mod_rows->* to <ft_mod_rows>.
    " Since we call data change event immediately after changing cell
    " objects mp_mod_rows and mt_mod_cells always have 1 record
    " so we read just at index 1
    read table <ft_mod_rows> assigning <fs_mod_rows> index 1.
    assign component 'CARRID' of structure <fs_mod_rows> to <fs>.

    lt_mod_cells = er_data_changed->mt_mod_cells.
    read table lt_mod_cells into ls_mod_cells index 1.

    lv_message = |Changed carrname: { <fs> }; changed data: { ls_mod_cells-value }|.
    message lv_message type 'S'.

  endmethod.
endclass.                    "lcl_event_handler IMPLEMENTATION
