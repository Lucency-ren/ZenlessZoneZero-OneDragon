from qfluentwidgets import FluentIcon

from one_dragon_qt.widgets.page_stack_wrapper import PageStackWrapper
from one_dragon_qt.widgets.pivot_navi_interface import PivotNavigatorInterface
from one_dragon_qt.widgets.setting_card.app_run_card import AppRunCard
from zzz_od.context.zzz_context import ZContext
from zzz_od.gui.view.one_dragon.predefined_team_interface import PredefinedTeamInterface
from zzz_od.gui.view.one_dragon.zzz_one_dragon_run_interface import (
    ZOneDragonRunInterface,
)


class ZOneDragonInterface(PivotNavigatorInterface):

    def __init__(self, ctx: ZContext, parent=None) -> None:
        self.ctx: ZContext = ctx
        PivotNavigatorInterface.__init__(
            self,
            nav_icon=FluentIcon.BUS,
            object_name='one_dragon_interface',
            parent=parent,
            nav_text_cn='一条龙',
        )

        self._app_run_cards: list[AppRunCard] = []

    def create_sub_interface(self) -> None:
        # 本地精简：一条龙只留运行页和队伍配置，体力规划与鼠标灵敏度检测不再挂载
        self.add_sub_interface(
            sub_interface=ZOneDragonRunInterface(self.ctx),
            enable_page_stack=True,
        )
        self.add_sub_interface(PredefinedTeamInterface(self.ctx))

    def on_interface_shown(self) -> None:
        if self.ctx.signal.start_onedragon:
            self.stacked_widget.setCurrentIndex(0)
            wrapper = self.stacked_widget.widget(0)
            if isinstance(wrapper, PageStackWrapper):
                wrapper.reset_to_root()
        super().on_interface_shown()
