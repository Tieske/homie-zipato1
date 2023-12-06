return require("cjson.safe").decode [[
{
    "templates": {
        "set_cmd": "zipato/zipabox-0107B6200D01C356/request/attributes/%s/textValue",
        "get_cmd": "zipato/zipabox-0107B6200D01C356/request/attributes/%s/getValue",
        "get_topic": "zipato/zipabox-0107B6200D01C356/attributes/%s/currentValue",
        "update_topic": "zipato/zipabox-0107B6200D01C356/attributes/%s/value"
    },
    "devices": {
        "thuis-stand": {
            "type": "Virtual switch",
            "model": "switch",
            "state": "a65920ad-3d23-4048-b1b7-f427d3025394"
        },
        "rafi-bedlamp-actor": {
            "type": "Fibaro FGS-211",
            "model": "switch",
            "state": "0ae57103-a8f0-404d-a3e7-f8aa2c922442"
        },
        "rafi-bedlamp-knop": {
            "type": "Fibaro FGS-211",
            "model": "switch",
            "state": "69ce9b85-96e9-4188-a8b3-3d9f636dc57f"
        },
        "noa-bedlamp-1": {
            "type": "Fibaro FGS-222",
            "model": "double-switch",
            "state": "28639ce0-fd3e-4912-b950-7f8054f298d5"
        },
        "noa-bedlamp-2": {
            "type": "Fibaro FGS-222",
            "model": "double-switch",
            "state": "8718b6f6-7e84-4aaa-98c1-f115f922c230"
        },
        "noa-hoofdlamp-1": {
            "type": "Fibaro FGS-222",
            "model": "double-switch",
            "state": "abe4b212-520f-400b-87d6-2c1d1c63dfb8"
        },
        "noa-hoofdlamp-2": {
            "type": "Fibaro FGS-222",
            "model": "double-switch",
            "state": "d282ae3c-2710-4148-a6a3-facc8e8eeae8"
        },
        "rafi-hoofdlamp-1": {
            "type": "Fibaro FGS-222",
            "model": "double-switch",
            "state": "035dd4fc-8ea0-4d80-b7bb-144d36b69025"
        },
        "rafi-hoofdlamp-2": {
            "type": "Fibaro FGS-222",
            "model": "double-switch",
            "state": "a6615e4d-61e6-42a4-8513-632f5777e662"
        },
        "badkamer-spots-spiegel-1": {
            "type": "Fibaro FGS-222",
            "model": "double-switch",
            "state": "f53a1c61-c90e-4e89-8faa-3432e8cbf6d2"
        },
        "badkamer-spots-spiegel-2": {
            "type": "Fibaro FGS-222",
            "model": "double-switch",
            "state": "4686f937-db8e-4143-ad77-86a4d6dde735"
        },
        "sensor-overloop": {
            "type": "Aeon Multi Sensor 6",
            "model": "sensor",
            "motion": "0da789a5-74eb-4aff-b2d1-3796976f1984",
            "humidity": "a4f26e23-1e5e-4c1f-8c10-b72ae5ac1676",
            "luminance": "d179387e-bc4f-4abb-8c26-4aac1198acc1",
            "temperature": "0b2d817b-9ef3-4506-bc96-37fd40b6f0fe"
        },
        "sensor-rafi": {
            "type": "Aeon Multi Sensor 6",
            "model": "sensor",
            "motion": "50be8e1f-948f-44d4-9c76-6217bf7d8e6d",
            "humidity": "9ce323a5-e4aa-4fdf-8e93-ec950af6c885",
            "luminance": "ac937aaa-d688-4032-82f0-3a7b9afb9d12",
            "temperature": "155449d2-9f88-4998-9d6b-5a17a82b0556"
        },
        "sensor-kids-badkamer": {
            "type": "Aeon Multi Sensor 6",
            "model": "sensor",
            "motion": "5ac2810a-019f-4de1-afb2-6bd6c3dcc8a1",
            "humidity": "c56faae8-15e8-4aef-87dc-dd414b5a43e0",
            "luminance": "f3dd5e62-4a50-44a7-ac35-d664feaf8df9",
            "temperature": "554e4f1d-4e12-48f0-8c4d-96a4a093a0a2"
        },
        "tv-chillroom": {
            "type": "Philio PAN-16",
            "model": "switch",
            "state": "7cebce9a-9fa4-468d-a789-92929a67b1fc",
            "current-consumption": "b0887e61-5f9f-4f1e-9beb-09afa00f36d3"
        },
        "plafond-rafi-1": {
            "type": "ZMNHBDx Flush 2 Relays Module",
            "model": "double-switch",
            "state": "2626bd85-c065-40d5-bf0e-9d58f5ab6d35"
        },
        "plafond-rafi-2": {
            "type": "ZMNHBDx Flush 2 Relays Module",
            "model": "double-switch",
            "state": "7c72aa1c-b26f-4e38-8112-4f1ba294bd14"
        },
        "lucht-beneden-inlaat-1": {
            "type": "ZMNHBDx Flush 2 Relays Module",
            "model": "double-switch",
            "state": "8a88d097-1ce7-4903-9ea5-69aa5452e0ba"
        },
        "lucht-beneden-inlaat-2": {
            "type": "ZMNHBDx Flush 2 Relays Module",
            "model": "double-switch",
            "state": "437f1b2a-b69c-46b7-a503-b64154114686"
        },
        "wkmr-spots-zichtlijn": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "ab8c6ee7-5da7-464f-a861-cfaa87260385"
        },
        "garderobe-spots": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "4009302e-110a-47f9-9efd-49f693023a4e"
        },
        "kantoor-spots-muurzijde": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "ae85936b-247c-4682-a44a-dd1cb0759048"
        },
        "kantoor-spots-gangzijde": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "d5f79269-13ce-46ee-b801-381ebc835437"
        },
        "overloop-spots": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "8f855bc2-59dd-430c-a22f-bf3e2089f9b2"
        },
        "badkamer-kids-spiegel-lamp": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "6a7478d5-8600-453f-8131-191e31a8c269"
        },
        "wkmr-spots-tv": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "fc1c04c6-3228-43e5-9e1f-c2571f64b7c1"
        },
        "keuken-spots-1-servies": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "1d0f027a-0490-4352-946d-8c5153957fc4"
        },
        "keuken-spots-2-koelkast": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "b5abb844-3443-4fb4-afc3-72c9b65e7f8e"
        },
        "keuken-spots-3-deur": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "a6329dcf-8113-4fed-a69a-33409c4ce961"
        },
        "keuken-spots-4-vriezer": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "5db41cee-a334-4400-bcb1-bca1f7a82af0"
        },
        "keuken-spots-5-speelgoed": {
            "type": "Qubino dimmer",
            "model": "dimmer",
            "level": "71d159a4-2224-4287-a1c2-a89ff4978f76"
        },
        "thermostaat-bk-kids": {
            "type": "Secure Thermostat",
            "model": "thermostat",
            "temperature": "b88ab0d7-b34f-4f57-8b69-82c20cb54a8d",
            "setpoint": "4368038a-825d-4da5-bd1e-1b0d282ea3f4"
        },
        "thermostaat-ellen": {
            "type": "Secure Thermostat",
            "model": "thermostat",
            "temperature": "0a50ca9d-c9d6-4891-b9da-6402ca89da6b",
            "setpoint": "f48581f0-87b3-40d4-9dd3-a8ecf9aa7384"
        },
        "thermostaat-wkmr": {
            "type": "Secure Thermostat",
            "model": "thermostat",
            "temperature": "999caff9-851b-4c1b-9cf4-b3385a21fe1d",
            "setpoint": "0b6b7c79-d398-4831-b534-e94d9f6e9124"
        },
        "thermostaat-garderobe": {
            "type": "Secure Thermostat",
            "model": "thermostat",
            "temperature": "229de984-75b7-469e-8618-a86c636f5eb6",
            "setpoint": "5f8c6666-8b87-4e23-9b3d-608d7f132ba9"
        }
    }
}
]]
