import Types exposing (..)
import Html exposing (Html)
import Utilities as Utils
import Interface as Iface
import Components as Comp
import Dict exposing (Dict)
import Comms


main = Html.program
  { init = init
  , update = update
  , subscriptions = subscriptions
  , view = view
  }


init : ( Model , Cmd Msg )
init =
  let
    pgrm = Init
    conf =
      { srvr = ""
      , tick = 20
      , mode = Kiosk
      }
  in
      ( { pgrm = pgrm, conf = conf }
      , Comms.pull_survey conf     )


update : Msg -> Model -> ( Model , Cmd Msg )
update msg model =
  case model.pgrm of
    -- if program is initializing, await server comms.
    Init -> 
      case msg of
        -- response from server.
        Recv rsp ->
          let
            pgrm = case Comms.process_rsp Nothing rsp of
              Just pgrm -> Run pgrm
              Nothing -> Init
          in
            ( { model | pgrm = pgrm }
            , Cmd.none              )

        -- all other messages are errors.
        _ ->
          let _ = Debug.log "unexpected msg" msg
          in ( model, Cmd.none )

    -- if program is running, handle all `Msg` types.
    Run pgrm ->
      case msg of
        Recv rsp ->
          let
            updated = case Comms.process_rsp (Just pgrm) rsp of
              Just pgrm -> Run pgrm
              Nothing -> model.pgrm
          in
            ( { model | pgrm = updated }
            , Cmd.none )

        User input ->
          let
            (updated,cmd) = Iface.apply_input pgrm input
          in
            ( { model | pgrm = Run updated }
            , cmd )

        Save response ->
          let
            updated = Utils.add_response response pgrm
            push = Comms.push_archive model.conf
          in
            ( { model | pgrm = Run updated }
            , push updated.arch )

    -- if program is finished, do nothing.
    Fin ->
      ( model , Cmd.none )




subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


view : Model -> Html Msg
view { pgrm, conf } =
  case pgrm of
    Init ->
      Comp.splash "loading..."

    Run pgrm ->
      case conf.mode of
        Kiosk ->
          Iface.render_kiosk conf pgrm

        Form ->
          Iface.render_form conf pgrm
 
    Fin ->
      Comp.splash "Thank You!"



