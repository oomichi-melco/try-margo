# Integration Patterns

This document describes how the Margo components can be deployed depending on the environment.

## Components

| Component | Description |
|-----------|-------------|
| WFM | Workload Fleet Manager. Manages applications and distributes them to devices. |
| Gateway | Lets one or several non-Margo devices connect to and be managed by a WFM, by translating the communication between them. It can run on a server, within a device, or on a dedicated device (a gateway device). In these patterns it is the only component that crosses a network boundary. |
| Device | An edge device that runs the deployed applications. Behind a Gateway it is a non-Margo device that is managed as a Margo device. A workload fleet management client is not required on a device behind a see-thru Gateway (see the [device requirements](https://github.com/margo/specification/blob/main/system-design/specification/margo-devices/device-requirements.md)). |

Per the [official documentation](https://docs.margo.org/concepts/gateways/gateways), Gateways are divided into three types:

- **Transparent**: not visible to the WFM. Provides a Margo client per downstream device, so each device appears as a Margo device.
- **See-thru**: visible to the WFM. Hosts a single Margo client for all downstream devices, and each device is still visible to the WFM with its own capabilities.
- **Opaque**: hides the downstream devices and appears to the WFM as a single Margo device with their combined capabilities.

The diagrams are written in [Mermaid](https://mermaid.js.org/) and rendered by GitHub.

## Pattern 1: Cloud WFM, one Gateway with multiple Devices

The WFM runs in the cloud. A single Gateway in the factory aggregates multiple Devices.

```mermaid
flowchart LR
    subgraph Cloud
        WFM[WFM]
    end
    subgraph Factory
        GW[Gateway]
        D1[Device 1]
        D2[Device 2]
        D3[Device 3]
    end
    WFM <--> GW
    GW <--> D1
    GW <--> D2
    GW <--> D3
```

## Pattern 2: Cloud WFM, multiple Gateway-Device sets

The WFM runs in the cloud. The factory has multiple sets, and each Gateway is connected to exactly one Device.

```mermaid
flowchart LR
    subgraph Cloud
        WFM[WFM]
    end
    subgraph Factory
        subgraph Set1[Set 1]
            GW1[Gateway 1] <--> D1[Device 1]
        end
        subgraph Set2[Set 2]
            GW2[Gateway 2] <--> D2[Device 2]
        end
        subgraph Set3[Set 3]
            GW3[Gateway 3] <--> D3[Device 3]
        end
    end
    WFM <--> GW1
    WFM <--> GW2
    WFM <--> GW3
```

## Pattern 3: Everything on-premises in the factory

The WFM, the Gateway and the Devices are all in the factory. The WFM is on the on-premises IT network and the Devices are on the OT network of the production line. A single Gateway bridges both networks.

```mermaid
flowchart LR
    subgraph Factory
        subgraph IT[On-premises IT network]
            WFM[WFM]
        end
        GW[Gateway]
        subgraph OT[Production line OT network]
            D1[Device 1]
            D2[Device 2]
        end
    end
    WFM <--> GW
    GW <--> D1
    GW <--> D2
```
