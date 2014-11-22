require "spec_helper"


context 'core alert contex' do

  specify 'should do something' do
    before {Alert::BusAlert.delete_all}
    Alert.add_alert(bus_line: 913, bus_stop: 72843, user: "@lucaa76")
    Alert.get_alert(bus_line: 913, bus_stop: 72843).alert_data.should == ["@lucaa76", [ 72805, 72805, 72843]]
    Alert.add_alert(bus_line: 913, bus_stop: 75772, user: "@lucaa76")
    Alert.get_alert(bus_line: 913, bus_stop: 72843).alert_data.should == ["@lucaa76", [ 72805, 72805, 72843,75770, 75770, 75772]]
    true.should == false
  end
end