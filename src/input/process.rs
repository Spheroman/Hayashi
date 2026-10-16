//! Input event processing
//!
//! Translates raw input events from the backend into Wayland protocol events
//! and compositor actions. Compositor keybindings (Mod+key) are intercepted
//! and dispatched as Actions; all other keys are forwarded to the focused client.

use smithay::backend::input::{
    AbsolutePositionEvent, Axis, AxisSource, ButtonState, Event, InputBackend, InputEvent,
    KeyState, KeyboardKeyEvent, PointerAxisEvent, PointerButtonEvent,
};
use smithay::input::keyboard::FilterResult;
use smithay::input::pointer::{AxisFrame, ButtonEvent, MotionEvent};
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::utils::SERIAL_COUNTER;
use xkbcommon::xkb::keysyms;

use super::action::Action;
use crate::Hayashi;

impl Hayashi {
    pub fn process_input_event<I: InputBackend>(&mut self, event: InputEvent<I>) {
        match event {
            InputEvent::Keyboard { event, .. } => {
                let serial = SERIAL_COUNTER.next_serial();
                let time = Event::time_msec(&event);
                let key_state = event.state();

                let action = self.seat.get_keyboard().unwrap().input::<Action, _>(
                    self,
                    event.key_code(),
                    key_state,
                    serial,
                    time,
                    |_, modifiers, handle| {
                        if key_state != KeyState::Pressed {
                            return FilterResult::Forward;
                        }

                        let keysym: u32 = handle.modified_sym().into();

                        if modifiers.logo {
                            // Mod+Shift combos
                            if modifiers.shift {
                                if keysym == keysyms::KEY_Q || keysym == keysyms::KEY_q {
                                    return FilterResult::Intercept(Action::CloseWindow);
                                }
                                if keysym == keysyms::KEY_E || keysym == keysyms::KEY_e {
                                    return FilterResult::Intercept(Action::Exit);
                                }
                                if keysym == keysyms::KEY_H || keysym == keysyms::KEY_h {
                                    return FilterResult::Intercept(Action::FocusLeft);
                                }
                                if keysym == keysyms::KEY_J || keysym == keysyms::KEY_j {
                                    return FilterResult::Intercept(Action::FocusDown);
                                }
                                if keysym == keysyms::KEY_K || keysym == keysyms::KEY_k {
                                    return FilterResult::Intercept(Action::FocusUp);
                                }
                                if keysym == keysyms::KEY_L || keysym == keysyms::KEY_l {
                                    return FilterResult::Intercept(Action::FocusRight);
                                }
                                if keysym == keysyms::KEY_Tab
                                    || keysym == keysyms::KEY_ISO_Left_Tab
                                {
                                    return FilterResult::Intercept(Action::FocusPrev);
                                }
                            }

                            // Mod+Shift+u: focus parent workspace
                            // Mod+Shift+d: focus child workspace
                            if modifiers.shift {
                                if keysym == keysyms::KEY_U || keysym == keysyms::KEY_u {
                                    return FilterResult::Intercept(Action::FocusParent);
                                }
                                if keysym == keysyms::KEY_D || keysym == keysyms::KEY_d {
                                    return FilterResult::Intercept(Action::FocusChild);
                                }
                            }

                            // Mod+Ctrl combos: zone and move management
                            if modifiers.ctrl && !modifiers.shift {
                                if keysym == keysyms::KEY_s || keysym == keysyms::KEY_S {
                                    return FilterResult::Intercept(Action::SplitZoneH);
                                }
                                if keysym == keysyms::KEY_v || keysym == keysyms::KEY_V {
                                    return FilterResult::Intercept(Action::SplitZoneV);
                                }
                                if keysym == keysyms::KEY_m || keysym == keysyms::KEY_M {
                                    return FilterResult::Intercept(Action::MergeZones);
                                }
                                // Move workspace to adjacent zone
                                if keysym == keysyms::KEY_h || keysym == keysyms::KEY_H {
                                    return FilterResult::Intercept(Action::MoveLeft);
                                }
                                if keysym == keysyms::KEY_j || keysym == keysyms::KEY_J {
                                    return FilterResult::Intercept(Action::MoveDown);
                                }
                                if keysym == keysyms::KEY_k || keysym == keysyms::KEY_K {
                                    return FilterResult::Intercept(Action::MoveUp);
                                }
                                if keysym == keysyms::KEY_l || keysym == keysyms::KEY_L {
                                    return FilterResult::Intercept(Action::MoveRight);
                                }
                            }

                            // Mod+Tab (without shift)
                            if !modifiers.shift && keysym == keysyms::KEY_Tab {
                                return FilterResult::Intercept(Action::FocusNext);
                            }

                            // Mod+letter (without shift/ctrl): workspace switching
                            if !modifiers.shift && !modifiers.ctrl {
                                if keysym >= keysyms::KEY_a && keysym <= keysyms::KEY_z {
                                    let ch = (keysym as u8) as char;
                                    return FilterResult::Intercept(
                                        Action::SwitchWorkspace(ch),
                                    );
                                }
                            }
                        }

                        FilterResult::Forward
                    },
                );

                if let Some(action) = action {
                    self.handle_action(action);
                }
            }
            InputEvent::PointerMotion { .. } => {}
            InputEvent::PointerMotionAbsolute { event, .. } => {
                // No output (e.g. all monitors off): nowhere to map the
                // pointer to, so drop the event.
                let Some(output_geo) = self
                    .space
                    .outputs()
                    .next()
                    .and_then(|output| self.space.output_geometry(output))
                else {
                    return;
                };

                let pos =
                    event.position_transformed(output_geo.size) + output_geo.loc.to_f64();

                let serial = SERIAL_COUNTER.next_serial();
                let pointer = self.seat.get_pointer().unwrap();
                let under = self.surface_under(pos);

                pointer.motion(
                    self,
                    under,
                    &MotionEvent {
                        location: pos,
                        serial,
                        time: event.time_msec(),
                    },
                );
                pointer.frame(self);
            }
            InputEvent::PointerButton { event, .. } => {
                let pointer = self.seat.get_pointer().unwrap();
                let keyboard = self.seat.get_keyboard().unwrap();

                let serial = SERIAL_COUNTER.next_serial();
                let button = event.button_code();
                let button_state = event.state();

                if ButtonState::Pressed == button_state && !pointer.is_grabbed() {
                    if let Some((window, _loc)) = self
                        .space
                        .element_under(pointer.current_location())
                        .map(|(w, l)| (w.clone(), l))
                    {
                        // Find the window index and update focused_window
                        let idx = self.windows.iter().position(|w| w == &window);
                        self.focused_window = idx;

                        self.space.raise_element(&window, true);
                        keyboard.set_focus(
                            self,
                            Some(window.toplevel().unwrap().wl_surface().clone()),
                            serial,
                        );
                        // Mark focused window as activated, others as deactivated
                        for w in self.space.elements() {
                            w.set_activated(Some(&window) == Some(w));
                            w.toplevel().unwrap().send_pending_configure();
                        }
                    } else {
                        self.focused_window = None;
                        self.space.elements().for_each(|window| {
                            window.set_activated(false);
                            window.toplevel().unwrap().send_pending_configure();
                        });
                        keyboard.set_focus(self, Option::<WlSurface>::None, serial);
                    }
                }

                pointer.button(
                    self,
                    &ButtonEvent {
                        button,
                        state: button_state,
                        serial,
                        time: event.time_msec(),
                    },
                );
                pointer.frame(self);
            }
            InputEvent::PointerAxis { event, .. } => {
                let source = event.source();

                let horizontal_amount = event
                    .amount(Axis::Horizontal)
                    .unwrap_or_else(|| {
                        event.amount_v120(Axis::Horizontal).unwrap_or(0.0) * 15.0 / 120.
                    });
                let vertical_amount = event
                    .amount(Axis::Vertical)
                    .unwrap_or_else(|| {
                        event.amount_v120(Axis::Vertical).unwrap_or(0.0) * 15.0 / 120.
                    });
                let horizontal_amount_discrete = event.amount_v120(Axis::Horizontal);
                let vertical_amount_discrete = event.amount_v120(Axis::Vertical);

                let mut frame = AxisFrame::new(event.time_msec()).source(source);

                if horizontal_amount != 0.0 {
                    frame = frame.value(Axis::Horizontal, horizontal_amount);
                    if let Some(discrete) = horizontal_amount_discrete {
                        frame = frame.v120(Axis::Horizontal, discrete as i32);
                    }
                }
                if vertical_amount != 0.0 {
                    frame = frame.value(Axis::Vertical, vertical_amount);
                    if let Some(discrete) = vertical_amount_discrete {
                        frame = frame.v120(Axis::Vertical, discrete as i32);
                    }
                }

                if source == AxisSource::Finger {
                    if event.amount(Axis::Horizontal) == Some(0.0) {
                        frame = frame.stop(Axis::Horizontal);
                    }
                    if event.amount(Axis::Vertical) == Some(0.0) {
                        frame = frame.stop(Axis::Vertical);
                    }
                }

                let pointer = self.seat.get_pointer().unwrap();
                pointer.axis(self, frame);
                pointer.frame(self);
            }
            _ => {}
        }
    }
}
