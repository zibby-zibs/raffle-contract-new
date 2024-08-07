import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";

const INTERVAL = 300;
const ENTRY_FEE = parseEther("0.01");
const AIRNODERRP = "0xD223DfDCb888CA1539bb3459a83c543A1608F038";

const RaffleModule = buildModule("RaffleModule", (m) => {
  const interval = m.getParameter("interval", INTERVAL);
  const entryFee = m.getParameter("entryFee", ENTRY_FEE);
  const airnoderrp = m.getParameter("airnoderrp", AIRNODERRP);

  const raffle = m.contract("Raffle", [interval, entryFee, airnoderrp], {});

  return { raffle };
});

export default RaffleModule;
